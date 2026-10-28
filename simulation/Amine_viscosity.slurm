#!/bin/bash
#SBATCH -p tyhcnormal

############################################################
# 1. RESP电荷计算阶段
############################################################
echo "Starting Stage 1: RESP Charge Calculation"
mol_list=("Amine" "AmineCOO" "AmineNH2")
declare -A resp_jobids

for mol in "${mol_list[@]}"; do
  # 创建目录并拷贝文件
  mkdir -p "./RESP/${mol}"
  cp "${mol}.pdb" "./RESP/${mol}/"
  cp RESP.sh "./RESP/${mol}/"
  
  # 生成分子专属的Slurm脚本
  cat > "./RESP/${mol}/${mol}_RESP.slurm" << EOF
#!/bin/bash
#SBATCH -p tyhcnormal
#SBATCH -J ${mol}_RESP
#SBATCH -N 2
#SBATCH --ntasks-per-node=32
#SBATCH --output=%x.log

cd ./RESP/${mol}
case "$mol" in
  Amine)    charge=0 ;;
  AmineCOO) charge=-1 ;;
  AmineNH2) charge=1 ;;
esac
./RESP.sh ${mol}.pdb \$charge 1 "2-Methyl-2-Propanol" "g16" "# B3LYP/def2TZVP em=GD3BJ opt=loose"
EOF

  # 提交作业并记录JobID
  resp_jobids["$mol"]=$(sbatch "./RESP/${mol}/${mol}_RESP.slurm" | awk '{print $4}')
  echo "Submitted ${mol}_RESP: JobID=${resp_jobids[$mol]}"
done

# 等待所有RESP作业完成
resp_dependencies="afterok:$(printf "%s:" "${resp_jobids[@]}")"
resp_dependencies=${resp_dependencies%:}  # 删除末尾多余的冒号
echo "Waiting for RESP jobs: ${resp_dependencies}"




############################################################
# 2. 拓扑文件处理阶段
############################################################
cat > itp_process.slurm << EOF
#!/bin/bash
#SBATCH -p tyhcnormal
#SBATCH -J itp_process
#SBATCH -N 1
#SBATCH --ntasks-per-node=4
#SBATCH --output=%x.log
#SBATCH --dependency=${resp_dependencies}

# 创建目录结构并处理文件
mkdir -p ./structure/Amine
mkdir -p ./structure/AmineCOO
mkdir -p ./structure/AmineNH2

# 复制PDB文件到对应目录
cp ./RESP/Amine/Amine.pdb ./structure/Amine/
cp ./RESP/AmineCOO/AmineCOO.pdb ./structure/AmineCOO/
cp ./RESP/AmineNH2/AmineNH2.pdb ./structure/AmineNH2/


# 复制电荷文件并重命名
cp ./RESP/Amine/Amine.chg ./structure/Amine/Amine.chg
cp ./RESP/AmineCOO/AmineCOO.chg ./structure/AmineCOO/AmineCOO.chg
cp ./RESP/AmineNH2/AmineNH2.chg ./structure/AmineNH2/AmineNH2.chg


# 复制ITP和PDB文件到对应目录
cp Amine.itp Amine.pdb ./structure/Amine/
cp AmineCOO.itp AmineCOO.pdb ./structure/AmineCOO/
cp AmineNH2.itp AmineNH2.pdb ./structure/AmineNH2/


# 在每个目录执行电荷替换脚本
cd ./structure/Amine
python /work/home/xuwenhao/dataprocess/replace_charges.py Amine.chg Amine.itp Amine_NEW.itp
cd ../AmineCOO
python /work/home/xuwenhao/dataprocess/replace_charges.py AmineCOO.chg AmineCOO.itp AmineCOO_NEW.itp
cd ../AmineNH2
python /work/home/xuwenhao/dataprocess/replace_charges.py AmineNH2.chg AmineNH2.itp AmineNH2_NEW.itp


# 修改ITP文件中的opls前缀
sed -i 's/opls/Aopls/g' ../Amine/Amine_NEW.itp
sed -i 's/opls/Copls/g' ../AmineCOO/AmineCOO_NEW.itp
sed -i 's/opls/Nopls/g' ../AmineNH2/AmineNH2_NEW.itp


cd ../..




EOF

topo_jobid=$(sbatch itp_process.slurm | awk '{print $4}')
echo "Submitted itp_process: JobID=$topo_jobid"


############################################################
# 3. PACKMOL盒子构建（与阶段1并行）
############################################################
loadings=(0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40)
declare -A packmol_jobids

for loading in "${loadings[@]}"; do
  # 动态计算分子数量
  Y_COUNT=$(echo "2000 * $loading" | bc | awk '{printf "%.0f", $1}')
  X_COUNT=$((2000 - 2 * Y_COUNT))
  
  # 生成PACKMOL输入文件（动态处理X_COUNT=0和Y_COUNT=0）
  {
    echo "tolerance 2.0"
    echo "add_box_sides 4"
    echo "output mix_${loading}.pdb"
    
    # 仅当X_COUNT>0时添加Amine.pdb结构块
    if [ "$X_COUNT" -gt 0 ]; then
      echo "structure Amine.pdb"
      echo "    number $X_COUNT"
      echo "    inside box 0. 0. 0. 70. 70. 210."
      echo "end structure"
    fi
    
    # 仅当Y_COUNT>0时添加AmineCOO/AmineNH2结构块
    if [ "$Y_COUNT" -gt 0 ]; then
      echo "structure AmineCOO.pdb"
      echo "    number $Y_COUNT"
      echo "    inside box 0. 0. 0. 70. 70. 210."
      echo "end structure"
      echo "structure AmineNH2.pdb"
      echo "    number $Y_COUNT"
      echo "    inside box 0. 0. 0. 70. 70. 210."
      echo "end structure"
    fi
  } > "packmol_${loading}.inp"

# 创建自适应扩容脚本（修复超时逻辑）
cat > "packmol_${loading}.slurm" << EOF
#!/bin/bash
#SBATCH -p tyhcnormal
#SBATCH -J packmol_${loading}
#SBATCH -N 1
#SBATCH --ntasks-per-node=4
#SBATCH --output=%x.log

# ====== 历史成功文件检查 ======
if [ -f "mix_${loading}_success.pdb" ]; then
    echo "[INFO] Found existing success file. Skipping calculation."
    exit 0
fi

max_retries=5
retry_count=0
box_size=(70 70 210)

while [ \$retry_count -lt \$max_retries ]; do
    log="packmol_${loading}_attempt_\${retry_count}.log"
    echo "=== Attempt \$((retry_count+1)) ===" > "\$log"
    
    # 运行PACKMOL（带超时）
    timeout 900 packmol < packmol_${loading}.inp >> "\$log" 2>&1
    exit_status=\$?
    
    sync && sleep 1  # 确保文件系统同步[3](@ref)
    
    # ====== 双重成功验证 ======
    if grep -q "Running time:" "\$log" && [ -f "mix_${loading}.pdb" ]; then
        mv "mix_${loading}.pdb" "mix_${loading}_success.pdb"
        echo "PACKML success at retry \$retry_count" | tee -a "\$log"
        exit 0
    fi

    # ====== 错误分类处理 ======
    if [ \$exit_status -eq 124 ]; then
        echo "[WARN] Timeout after 15 minutes" | tee -a "\$log"
    elif [ \$exit_status -ne 0 ]; then
        echo "[ERROR] Packmol exited with code \$exit_status" | tee -a "\$log"
    else
        echo "[WARN] No success marker in log" | tee -a "\$log"
    fi

    # ====== 扩容重试逻辑 ======
    for i in {0..2}; do
        box_size[i]=\$(echo "\${box_size[i]} * 1.2" | bc -l | awk '{printf "%.2f", \$1}')
    done
    echo "Resizing box to \${box_size[0]} x \${box_size[1]} x \${box_size[2]}" | tee -a "\$log"
    sed -i "s|inside box.*|inside box 0. 0. 0. \${box_size[0]} \${box_size[1]} \${box_size[2]}|" packmol_${loading}.inp
    
    ((retry_count++))
done

# ====== 最终失败处理 ======
echo "PACKML failed after \$max_retries retries!"
cp packmol_${loading}.inp "FAILED_config.inp"  # 保存失败配置[6](@ref)
exit 1
EOF

  packmol_jobids["$loading"]=$(sbatch "packmol_${loading}.slurm" | awk '{print $4}')
  echo "Submitted packmol_${loading}: JobID=${packmol_jobids[$loading]}"
done


###########################################################
# 4. GROMACS计算（依赖阶段2和3）
############################################################
for loading in "${loadings[@]}"; do
  # 创建GROMACS提交脚本
  clean_resp_deps="${resp_dependencies#afterok:}"
  gromacs_deps="afterok:$topo_jobid:${packmol_jobids[$loading]}:$clean_resp_deps"
  
  cat > "gromacs_${loading}.slurm" << EOF
#!/bin/bash
#SBATCH -p tyhcnormal
#SBATCH -J gromacs_${loading}
#SBATCH -N 4
#SBATCH --ntasks-per-node=32
#SBATCH --output=%x.log
#SBATCH --dependency=$gromacs_deps

mkdir -p "./gromacs_results/CO2_loading_${loading}"
cp gromacs_viscosity.sh "./gromacs_results"
cp "mix_${loading}_success.pdb" "./gromacs_results/CO2_loading_${loading}/mix.pdb"
cd "./gromacs_results/CO2_loading_${loading}"
mpirun -n 1 gmx_mpi editconf -f mix.pdb -o mix.gro
cd ..
cd ..

python /work/home/xuwenhao/dataprocess/process_gromacs_files.py ${loading}
WORK_DIR=\$(pwd -P)
TARGET_DIR="\$WORK_DIR/gromacs_results/CO2_loading_${loading}"
cd "\$TARGET_DIR"

export GMX_MAXBACKUP=-1
../gromacs_viscosity.sh mix.gro mix.top "\$TARGET_DIR"
EOF

  # 提交作业并添加间隔
  sbatch gromacs_${loading}.slurm
  echo "Submitted gromacs_${loading}: 依赖拓扑($topo_jobid) + PACKML(${packmol_jobids[$loading]}) + RESP($resp_dependencies)"
  
  # 添加1分钟间隔（最后一个作业不等待）
  if [[ $loading != ${loadings[-1]} ]]; then
    sleep 30
  fi
done