#!/bin/bash
#SBATCH -p tyhcnormal
#SBATCH -J Summary
#SBATCH -N 1
#SBATCH --ntasks-per-node=1


# 脚本用法：sbatch do_calculation.slurm <序号>，如：sbatch do_calculation.slurm 1 或 1,3,5-7
# 功能：读取 smiles_summary.xlsx → 生成 Amine/AmineNH2/AmineCOO 文件 → 运行 LigParGen
# 修改：增加文件存在检查，避免重复生成

# 设置路径
EXCEL_FILE="smiles_summary.xlsx"
SCRIPT_DIR="/work/home/xuwenhao/Viscosity_cal/script"  # 修改为你的公用脚本目录（可选）

# 检查 Excel 文件
if [ ! -f "$EXCEL_FILE" ]; then
    echo "错误: 未找到 $EXCEL_FILE" >&2
    exit 1
fi

# 解析输入序号（支持 1,3,5-7）
parse_sequence() {
    local input="$1"
    local result=()
    IFS=',' read -ra parts <<< "$input"
    for part in "${parts[@]}"; do
        if [[ "$part" =~ ^[0-9]+-[0-9]+$ ]]; then
            local start="${part%-*}"
            local end="${part#*-}"
            for ((i=start; i<=end; i++)); do
                result+=("$i")
            done
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            result+=("$part")
        else
            echo "警告: 忽略无效格式 '$part'" >&2
        fi
    done
    echo "${result[@]}"
}

# 安全读取 SMILES（仅输出 SMILES，禁止调试 print）
get_smiles() {
    local index="$1"
    local column="$2"
    python3 - << EOF
import pandas as pd
import sys
try:
    df = pd.read_excel("$EXCEL_FILE", engine='openpyxl')
    # 清理列名
    df.columns = [col.strip() for col in df.columns]
    # 确保序号为数字
    if '吸收剂序号' in df.columns:
        df['吸收剂序号'] = pd.to_numeric(df['吸收剂序号'], errors='coerce')
    else:
        print("错误: 列 '吸收剂序号' 不存在", file=sys.stderr)
        print("")
        sys.exit(1)
    
    row = df[df['吸收剂序号'] == $index]
    if not row.empty and pd.notna(row['$column'].iloc[0]):
        smiles = str(row['$column'].iloc[0]).strip()
        print(smiles)
    else:
        print("")
except Exception as e:
    print(f"Python 读取错误: {e}", file=sys.stderr)
    print("")
EOF
}

# 检查文件是否存在的函数[1,3](@ref)
check_files_exist() {
    local base_name="$1"
    # 检查主要的输出文件是否存在[6](@ref)
    if [ -f "${base_name}.itp" ] && [ -f "${base_name}.gro" ] && [ -f "${base_name}.pdb" ]; then
        return 0  # 文件存在
    else
        return 1  # 文件不存在
    fi
}

# ========= 主逻辑 =========
if [ $# -ne 1 ]; then
    echo "用法: sbatch $0 <序号，例如 1 或 1,3 或 5-7>" >&2
    exit 1
fi

sequence="$1"
indices=($(parse_sequence "$sequence"))
if [ ${#indices[@]} -eq 0 ]; then
    echo "错误: 未解析到有效序号！" >&2
    exit 1
fi

echo "开始处理序号: ${indices[@]}"

for index in "${indices[@]}"; do
    echo "=== 处理序号 $index ==="

    # 读取三种 SMILES
    amine_smile=$(get_smiles "$index" "Amine_SMILE")
    aminenh2_smile=$(get_smiles "$index" "AmineNH2_SMILE")
    aminecoo_smile=$(get_smiles "$index" "AmineCOO_SMILE")

    if [ -z "$amine_smile" ] && [ -z "$aminenh2_smile" ] && [ -z "$aminecoo_smile" ]; then
        echo "警告: 序号 $index 在 Excel 中无有效 SMILES，跳过。"
        continue
    fi

    # 创建目录
    dir="$index"
    if [ ! -d "$dir" ]; then
        mkdir "$dir"
        echo "创建目录: $dir"
    else
        echo "目录已存在: $dir"
    fi
    cd "$dir" || { echo "无法进入 $dir"; exit 1; }

    # 生成 Amine (电荷 0) - 增加文件存在检查[6](@ref)
    if [ -n "$amine_smile" ]; then
        if check_files_exist "Amine"; then
            echo "Amine 文件已存在，跳过生成。"
        else
            echo "生成 Amine (charge 0): $amine_smile"
            # 确保 LigParGen 目录存在
            mkdir -p ./LigParGen/Amine
            ligpargen -s "$amine_smile" -n Amine -p ./LigParGen/Amine -r UKN -c 0 -o 3 -cgen CM1A
            if [ $? -eq 0 ]; then
                echo "Amine 生成成功"
                # 移动并重命名文件
                mv ./LigParGen/Amine/Amine.openmm.pdb ./Amine.pdb 2>/dev/null
                mv ./LigParGen/Amine/Amine.gmx.gro ./Amine.gro 2>/dev/null
                mv ./LigParGen/Amine/Amine.gmx.itp ./Amine.itp 2>/dev/null
                echo "Amine 文件移动完成"
            else
                echo "Amine 生成失败" >&2
            fi
        fi
    fi

    # 生成 AmineNH2 (电荷 +1) - 增加文件存在检查
    if [ -n "$aminenh2_smile" ]; then
        if check_files_exist "AmineNH2"; then
            echo "AmineNH2 文件已存在，跳过生成。"
        else
            echo "生成 AmineNH2 (charge +1): $aminenh2_smile"
            mkdir -p ./LigParGen/AmineNH2
            ligpargen -s "$aminenh2_smile" -n AmineNH2 -p ./LigParGen/AmineNH2 -r UKN -c 1 -o 3 -cgen CM1A
            if [ $? -eq 0 ]; then
                echo "AmineNH2 生成成功"
                # 移动并重命名文件
                mv ./LigParGen/AmineNH2/AmineNH2.openmm.pdb ./AmineNH2.pdb 2>/dev/null
                mv ./LigParGen/AmineNH2/AmineNH2.gmx.gro ./AmineNH2.gro 2>/dev/null
                mv ./LigParGen/AmineNH2/AmineNH2.gmx.itp ./AmineNH2.itp 2>/dev/null
                echo "AmineNH2 文件移动完成"
            else
                echo "AmineNH2 生成失败" >&2
            fi
        fi
    fi

    # 生成 AmineCOO (电荷 -1) - 增加文件存在检查
    if [ -n "$aminecoo_smile" ]; then
        if check_files_exist "AmineCOO"; then
            echo "AmineCOO 文件已存在，跳过生成。"
        else
            echo "生成 AmineCOO (charge -1): $aminecoo_smile"
            mkdir -p ./LigParGen/AmineCOO
            ligpargen -s "$aminecoo_smile" -n AmineCOO -p ./LigParGen/AmineCOO -r UKN -c -1 -o 3 -cgen CM1A
            if [ $? -eq 0 ]; then
                echo "AmineCOO 生成成功"
                # 移动并重命名文件
                mv ./LigParGen/AmineCOO/AmineCOO.openmm.pdb ./AmineCOO.pdb 2>/dev/null
                mv ./LigParGen/AmineCOO/AmineCOO.gmx.gro ./AmineCOO.gro 2>/dev/null
                mv ./LigParGen/AmineCOO/AmineCOO.gmx.itp ./AmineCOO.itp 2>/dev/null
                echo "AmineCOO 文件移动完成"
            else
                echo "AmineCOO 生成失败" >&2
            fi
        fi
    fi

    # 拷贝公用脚本（可选）
    if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR" ]; then
        cp "$SCRIPT_DIR"/* . 2>/dev/null && echo "脚本已拷贝" || echo "拷贝脚本失败"
    fi

    # 提交后续作业（取消注释以启用）
    sbatch Amine_viscosity.slurm

    cd ..
done

echo "所有序号处理完成！日志: Summary.log 错误: Summary.err"