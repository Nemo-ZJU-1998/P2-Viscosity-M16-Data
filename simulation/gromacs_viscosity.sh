#!/bin/bash

# 初始化变量
INPUT_GRO="$1"     # 输入的 .gro 文件路径
INPUT_TOP="$2"     # 输入的 .top 文件路径
OUTPUT_DIR="$3"    # 输出结果目录
LOG_DIR="$OUTPUT_DIR/logs"
mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

# 设置OpenMP线程绑定
export MPI_PROCESSES=128   # 与Slurm中--cpus-per-task=2对应
export OMP_PLACES=cores
export OMP_PROC_BIND=spread,close


# 检查输入参数
if [ ! -f "$INPUT_GRO" ] || [ ! -f "$INPUT_TOP" ]; then
    echo "错误：输入文件缺失，请检查 $INPUT_GRO 和 $INPUT_TOP 是否存在。"  
    exit 1
fi

# 动态生成 MDP 文件记录到日志
echo "生成 MDP 文件..."  
MDP_DIR="$OUTPUT_DIR/mdp_files"
mkdir -p "$MDP_DIR"

# em.mdp
cat > "$MDP_DIR/em.mdp" <<EOF
; 能量最小化参数设置
integrator = steep
nsteps = 100000
emtol  = 10.0
emstep = 0.01
nstxout   = 100
nstlog    = 50
nstenergy = 10
pbc = xyz
cutoff-scheme = Verlet
coulombtype   = PME
rcoulomb      = 1.0
vdwtype       = Cut-off
rvdw          = 1.0
DispCorr      = EnerPres
constraints   = none
EOF

# md_heat_NPT.mdp
cat > "$MDP_DIR/md_heat_NPT.mdp" << EOF
; NPT模拟参数设置
integrator = md
dt         = 0.001
nsteps     = 500000
comm-grps  = system
nstxout = 1000
nstvout = 1000
nstfout = 1000
nstlog  = 500
nstenergy = 500
annealing = periodic
annealing_npoints = 4
annealing_time = 0 60 160 400
annealing_temp = 0 650 650 0
pbc = xyz
cutoff-scheme = Verlet
coulombtype   = PME
rcoulomb      = 1.0
vdwtype       = cut-off
rvdw          = 1.0
DispCorr      = EnerPres
Tcoupl  = V-rescale
tau_t   = 0.2
tc_grps = system
ref_t   = 298.15
Pcoupl     = berendsen
pcoupltype = isotropic
tau_p = 2.0
ref_p = 1.0
compressibility = 4.5e-5
gen_vel  = no
gen_seed = -1
;
freezegrps  = 
freezedim   = 
constraints = none
EOF

# md_NPT.mdp
cat > "$MDP_DIR/md_NPT.mdp" << EOF
; NPT2模拟参数设置
define =
integrator = md
dt         = 0.001   ; ps
nsteps     = 500000 ; 1ns
comm-grps  = system
energygrps = 
;
nstxout = 0
nstvout = 0
nstfout = 0
nstlog  = 1000
nstenergy = 1000
nstxout-compressed = 1000
compressed-x-grps  = system
;
pbc = xyz
cutoff-scheme = Verlet
coulombtype   = PME
rcoulomb      = 1.0
vdwtype       = cut-off
rvdw          = 1.0
DispCorr      = EnerPres
;
Tcoupl  = V-rescale
tau_t   = 0.2
tc_grps = system
ref_t   = 353
;
Pcoupl     = berendsen
pcoupltype = isotropic
tau_p = 2.0
ref_p = 1.0
compressibility = 4.5e-5
;
gen_vel  = no
gen_temp = 353
gen_seed = -1
;
constraint_algorithm = lincs
freezegrps  = 
freezedim   = 
constraints = none
EOF

# NVT.mdp
cat > "$MDP_DIR/NVT.mdp" <<EOF
; NVT模拟参数设置
integrator          = md
nsteps              = 1000000
dt                  = 0.001
nstxout             = 1000
nstvout             = 1000
nstenergy           = 1000
nstlog              = 1000
constraints         = none
cutoff-scheme       = Verlet
nstlist = 10
pbc                 = xyz
tcoupl              = V-rescale
tc-grps             = System
tau_t               = 0.2
ref_t               = 353
pcoupl              = no
EOF

# vis.mdp
cat > "$MDP_DIR/vis.mdp" <<EOF
; 粘度模拟参数
integrator          = md
nsteps              = 500000 
dt                  = 0.001
nstxout             = 100
nstvout             = 100
nstenergy           = 100
nstlog              = 1000
constraint_algorithm = Lincs
constraints         = none
lincs_iter = 1
lincs_order = 4
nstlist = 10
cutoff-scheme       = Verlet
rcoulomb = 1.4
rvdw = 1.4
coulombtype = PME
pme_order = 4
fourierspacing = 0.16
cos-acceleration    = 0.06
pbc                 = xyz
tcoupl              = nose-hoover
nh-chain-length          = 1
tc-grps             = System
tau_t               = 0.2
ref_t               = 353
pcoupl              = no
tau_p                    = 0.5
compressibility          = 4.5e-5
ref_p                    = 1.
EOF

# 温度列表  
TEMPERATURES=(313)


# Step 1: 能量最小化
echo "执行能量最小化..."  
if ! grep -q 'Finished mdrun' "$OUTPUT_DIR/em.log"; then  
    mpirun -n 1 gmx_mpi grompp -f "$MDP_DIR/em.mdp" -c "$INPUT_GRO" -p "$INPUT_TOP" -o "$OUTPUT_DIR/em.tpr" -maxwarn 5   
    mpirun -np 128 gmx_mpi mdrun -v -deffnm "$OUTPUT_DIR/em"
fi  

# Step 2: 升温退火NPT系综
echo "执行 升温退火NPT系综 模拟..."

# 定义检测完成的函数
check_finished() {
    # 检查所有可能的日志文件变体
    grep -q 'Finished mdrun' "$OUTPUT_DIR/md_heat_NPT.log" 2>/dev/null ||
    grep -q 'Finished mdrun' "$OUTPUT_DIR/md_heat_NPT.part"*.log 2>/dev/null ||
    grep -q 'Finished mdrun' "$OUTPUT_DIR/"md_heat_NPT*.log 2>/dev/null
}
update_gro_file() {
    # 查找最新的GRO文件 (排除备份文件)
    latest_gro=$(find "$OUTPUT_DIR" -name 'md_heat_NPT*.gro' -not -name '*prev*' \
                | sort -t. -k1V -k3n | tail -1)
    
    # 复制为统一文件名
    cp -v "$latest_gro" "$OUTPUT_DIR/md_heat_NPT.gro"
}
if ! check_finished; then
    # 检查是否存在检查点文件
    if [ -f "$OUTPUT_DIR/md_heat_NPT.cpt" ]; then
        # 存在检查点文件，进行续跑
        COORDINATE="$OUTPUT_DIR/md_heat_NPT.gro"
        # 确保结构文件存在
        if [ ! -f "$COORDINATE" ]; then
            COORDINATE="$OUTPUT_DIR/em.gro"
            echo "警告：使用em.gro作为替代，应检查上次运行是否正常结束"
        fi
        mpirun -n 1 gmx_mpi grompp -f "$MDP_DIR/md_heat_NPT.mdp" -c "$COORDINATE" -p "$INPUT_TOP" -o "$OUTPUT_DIR/md_heat_NPT.tpr" -maxwarn 5 -t "$OUTPUT_DIR/md_heat_NPT.cpt"
        mpirun -np $MPI_PROCESSES gmx_mpi mdrun -v -s "$OUTPUT_DIR/md_heat_NPT.tpr" -cpi "$OUTPUT_DIR/md_heat_NPT.cpt" -cpt 0.5 -dd 4 4 8 -deffnm "$OUTPUT_DIR/md_heat_NPT" -noappend
    else
        # 不存在检查点文件，正常运行
        mpirun -n 1 gmx_mpi grompp -f "$MDP_DIR/md_heat_NPT.mdp" -c "$OUTPUT_DIR/NVT_313.gro" -p "$INPUT_TOP" -o "$OUTPUT_DIR/md_heat_NPT.tpr" -maxwarn 5
        mpirun -np $MPI_PROCESSES gmx_mpi mdrun -v -cpi "$OUTPUT_DIR/md_heat_NPT.cpt" -cpt 0.5 -dd 4 4 8 -deffnm "$OUTPUT_DIR/md_heat_NPT"
    fi

    max_attempts=8  # 减少尝试次数避免无限循环
    for (( attempt = 1; attempt <= max_attempts; attempt++ )); do
        # 每次续跑前检查是否已完成
        if check_finished; then
            echo "检测到已完成，停止续跑"
            break
        fi
        
        if [ -f "$OUTPUT_DIR/md_heat_NPT.cpt" ]; then
            echo "尝试续跑 #$attempt"
            # 直接续跑，不重新生成tpr
            mpirun -np $MPI_PROCESSES gmx_mpi mdrun -v -s "$OUTPUT_DIR/md_heat_NPT.tpr" -cpi "$OUTPUT_DIR/md_heat_NPT.cpt" -cpt 0.5 -dd 4 4 8 -deffnm "$OUTPUT_DIR/md_heat_NPT" -noappend
        else
            echo "无检查点文件，无法续跑"
            break
        fi
    done
    
    # 最终检查所有可能的日志文件
    if ! check_finished; then
        echo "错误：NPT模拟在$max_attempts次尝试后仍未完成"
        exit 1
    fi
fi

cd "$OUTPUT_DIR"
update_gro_file
# 定义函数以动态获取编号
function get_energy_index {
    local edr_file="$1"      # Energy 文件路径
    local search_key="$2"    # 搜索的参数名称
    local index              # 保存找到的编号
    
    # 使用 gmx energy 的 ? 模式获取编号
    echo -e "0\n" | mpirun -n 1 gmx_mpi energy -f "$edr_file" >> "energy.log" 2>&1
    index=$(grep -i "$search_key" energy.log | awk -v key="$search_key" '{for(i=1; i<=NF; i++) if($i==key) print $(i-1)}')

    # 检查是否找到编号
    if [ -z "$index" ]; then
        echo "未找到参数 $search_key 的编号，请检查 energy 文件和参数名称。" >&2
        exit 1
    fi

    echo "$index"  # 返回找到的编号
}

# 确保 result 目录存在
mkdir result
rm -f energy.log


# 能量最小化 - 动态解析 Potential 的编号
POTENTIAL_INDEX=$(get_energy_index "em.edr" "Potential")
mpirun -n 1 gmx_mpi energy -f em.edr -o result/em_Potential.xvg << EOF
$POTENTIAL_INDEX
EOF
echo "能量最小化结果已保存 (Potential)。"
rm -f energy.log

# NPT1 - 动态解析 Density 的编号
DENSITY_INDEX=$(get_energy_index "md_heat_NPT.edr" "Density")
mpirun -n 1 gmx_mpi energy -f md_heat_NPT.edr -o result/md_heat_NPT_Density.xvg << EOF
$DENSITY_INDEX
EOF
echo "NPT1 结果已保存 (Density)。"
rm -f energy.log

# NPT1 - 动态解析 Temperature 的编号
Temperature_INDEX=$(get_energy_index "md_heat_NPT.edr" "Temperature")
mpirun -n 1 gmx_mpi energy -f md_heat_NPT.edr -o result/md_heat_NPT_Temperature.xvg << EOF
$Temperature_INDEX
EOF
echo "NPT 结果已保存 (Temperature)。"
rm -f energy.log

python3 /work/home/xuwenhao/dataprocess/em_Potential_plot.py result/em_Potential.xvg
python3 /work/home/xuwenhao/dataprocess/NPT_Temperature_density_plot.py result/md_heat_NPT_Density.xvg result/md_heat_NPT_Temperature.xvg


pwd


# 对不同温度进行模拟  
for TEMP in "${TEMPERATURES[@]}"; do  
    echo "当前温度: $TEMP K"    
    
    # Step 3: NPT 平衡  
    echo "执行 NPT 模拟..."    
    sed "s|ref_t.*|ref_t = $TEMP|" "$MDP_DIR/md_NPT.mdp" | sed "s|gen_temp.*|gen_temp = $TEMP|" > "$OUTPUT_DIR/md_NPT_${TEMP}.mdp"  
    if ! grep -q 'Finished mdrun' "$OUTPUT_DIR/md_NPT_${TEMP}.log"; then  
        mpirun -n 1 gmx_mpi grompp -f "$OUTPUT_DIR/md_NPT_${TEMP}.mdp" -c "$OUTPUT_DIR/md_heat_NPT.gro" -p "$INPUT_TOP" -o "$OUTPUT_DIR/md_NPT_${TEMP}.tpr" -maxwarn 5   
        mpirun -np 128 gmx_mpi mdrun -v -deffnm "$OUTPUT_DIR/md_NPT_${TEMP}"
    fi  

    # Step 4: NVT 模拟  
    echo "执行 NVT 模拟..."    
    sed "s|ref_t.*|ref_t = $TEMP|" "$MDP_DIR/NVT.mdp" > "$OUTPUT_DIR/NVT_${TEMP}.mdp"  
    if ! grep -q 'Finished mdrun' "$OUTPUT_DIR/NVT_${TEMP}.log"; then  
        mpirun -n 1 gmx_mpi grompp -f "$OUTPUT_DIR/NVT_${TEMP}.mdp" -c "$OUTPUT_DIR/md_NPT_${TEMP}.gro" -p "$INPUT_TOP" -o "$OUTPUT_DIR/NVT_${TEMP}.tpr" -maxwarn 5   
        mpirun -np 128 gmx_mpi mdrun -v -deffnm "$OUTPUT_DIR/NVT_${TEMP}"
    fi  


    # Step 5: 粘度模拟  
    echo "执行粘度模拟..."    
    ACCELERATIONS=(0.025 0.030 0.035 0.04 0.045 0.050)  
	declare -a job_ids  # 存储作业ID
	declare -a post_job_ids  # 存储后处理作业ID
	
    for ACC in "${ACCELERATIONS[@]}"; do  
        # 生成独立作业脚本
# 生成独立作业脚本
        cat > submit_${TEMP}_${ACC}.sh << EOF
#!/bin/bash
#SBATCH --job-name=vis_${TEMP}_${ACC}
#SBATCH -N 4 #节点数量
#SBATCH --ntasks-per-node=32  # 修改：每节点32 MPI进程（原来64）
#SBATCH -p tyhcnormal #队列名称

# 修改模板文件
sed "s|cos-acceleration.*|cos-acceleration = $ACC|" "$MDP_DIR/vis.mdp" | sed "s|ref_t.*|ref_t = $TEMP|" > "$OUTPUT_DIR/vis_${TEMP}_${ACC}.mdp"

# 检查并执行粘度模拟
if ! grep -q 'Finished mdrun' "$OUTPUT_DIR/vis_${TEMP}_${ACC}.log"; then  
    mpirun -n 1 gmx_mpi grompp -f "$OUTPUT_DIR/vis_${TEMP}_${ACC}.mdp" -c "$OUTPUT_DIR/NVT_${TEMP}.gro" -p "$INPUT_TOP" -o "$OUTPUT_DIR/vis_${TEMP}_${ACC}.tpr" -maxwarn 5   
    mpirun -np 128 gmx_mpi mdrun -v -deffnm "$OUTPUT_DIR/vis_${TEMP}_${ACC}"
fi


EOF

    # 提交作业并记录ID
        job_ids+=($(sbatch --parsable submit_${TEMP}_${ACC}.sh))
		job_ids+=($job_id)
    done

# 将作业ID数组转换为冒号分隔格式（Slurm依赖格式）
dependency_ids=$(IFS=:; echo "${job_ids[*]}")

# 创建后处理作业脚本
cat > post_process_${TEMP}.slurm <<EOF
#!/bin/bash
#SBATCH --job-name=post_${TEMP}
#SBATCH --dependency=afterany:$dependency_ids  # 依赖所有粘度作业
#SBATCH --output=${OUTPUT_DIR}/post_${TEMP}.out
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH -p tyhcnormal

cd $OUTPUT_DIR
/work/home/xuwenhao/dataprocess/edr_output.sh "$OUTPUT_DIR" "$TEMP" 0.025 0.030 0.035 0.04 0.045 0.050

python3 /work/home/xuwenhao/dataprocess/extract_energy_log.py post_${TEMP}.out
python3 /work/home/xuwenhao/dataprocess/extract_viscosity.py post_${TEMP}.out "313" "0.025 0.030 0.035 0.04 0.045 0.050"
python3 /work/home/xuwenhao/dataprocess/acc_vis_line_regression.py viscosity_summary.txt
EOF

post_job_id=$(sbatch --parsable post_process_${TEMP}.slurm)

    # 3. 提交后处理作业（顺序执行，依赖汇总作业完成）
    last_dependency="$post_job_id"
    for ACC in "${ACCELERATIONS[@]}"; do
        cat > post_vel_${TEMP}_${ACC}.slurm << EOF
#!/bin/bash
#SBATCH --job-name=postvel_${TEMP}_${ACC}
#SBATCH --dependency=afterany:$last_dependency  # 依赖前一个作业
#SBATCH --output=${OUTPUT_DIR}/post_vel_${TEMP}_${ACC}.out
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH -p tyhcnormal

# 后处理
mpirun -n 1 gmx_mpi trjconv -f "$OUTPUT_DIR/vis_${TEMP}_${ACC}.trr" -s "$OUTPUT_DIR/vis_${TEMP}_${ACC}.tpr" -o "$OUTPUT_DIR/traj_${ACC}.gro" -b 350 -e 450 << END
2
END

python3 /work/home/xuwenhao/dataprocess/velocity_profile.py -f "$OUTPUT_DIR/traj_${ACC}.gro" -o "$OUTPUT_DIR/zvx_${ACC}.xvg" --mode atom --dz 0.1 --plot "$OUTPUT_DIR/velocity_profile_${TEMP}_${ACC}.png"

if [[ -s "$OUTPUT_DIR/velocity_profile_${TEMP}_${ACC}.png" ]]; then
    echo "图像已生成，正在清除中间文件..."
    rm -f "$OUTPUT_DIR/traj_${ACC}.gro"
    rm -f "$OUTPUT_DIR/vis_${TEMP}_${ACC}.trr"
else
    echo "警告：未检测到图像文件 velocity_profile_${TEMP}_${ACC}.png，保留中间文件"
fi
EOF
        # 提交作业并更新依赖链
        job_id=$(sbatch --parsable post_vel_${TEMP}_${ACC}.slurm)
        last_dependency=$job_id  # 下一个作业依赖此作业
    done


done