#!/bin/bash

# 默认关键字和高斯版本
keyword_opt="# B3LYP/def2SVP em=GD3BJ opt=loose"
keyword_SP="# B3LYP/def2TZVP em=GD3BJ pop=MK IOp(6/33=2,6/42=6)"
Gaussian=g09  # 默认版本

# 处理输入参数
inname=$1       # 输入文件名
chg=$2          # 电荷（可选，默认 0）
multi=$3        # 自旋多重度（可选，默认 1）
solvent=$4      # 溶剂（可选，默认 water）
custom_Gaussian=$5  # 自定义 Gaussian 版本
custom_opt=$6       # 自定义优化关键字

# 提取文件名和扩展名
base_inname=$(basename "$inname")
prefix=${base_inname%.*}   # 提取文件名（不含扩展名）
chgname="${prefix}.chg"    # 输出的 .chg 文件名

# 检查是否已存在 .chg 文件
echo "Checking for existing .chg file..."
echo "Expected .chg file: $chgname"
echo "Current directory: $(pwd)"
echo "Files in the directory:"
ls -l

if [ -f "$chgname" ]; then
    echo "Detected existing .chg file: $chgname"
    echo "Skipping Gaussian and Multiwfn calculations."
    echo "To force re-run, delete $chgname and re-execute the script."
    exit 0
else
    echo "No .chg file found. Proceeding with Gaussian and Multiwfn calculations."
fi




# 设置默认值
if [ -z "$chg" ]; then
    chg=0
fi

if [ -z "$multi" ]; then
    multi=1
fi

if [ -z "$solvent" ]; then
    solvent="scrf(solvent=water)"
else
    solvent="scrf(solvent=$solvent)"
fi

if [ -n "$custom_Gaussian" ]; then
    Gaussian=$custom_Gaussian  # 使用传递的高斯版本
fi

if [ -n "$custom_opt" ]; then
    keyword_opt=$custom_opt    # 使用传递的优化关键字
fi

# 添加溶剂到关键字
keyword_opt="$keyword_opt $solvent"
keyword_SP="$keyword_SP $solvent"

echo "Using Gaussian version: $Gaussian"
echo "Optimization keywords: $keyword_opt"

# Step 1: Multiwfn 生成 tmp.xyz
echo "Running Multiwfn to generate tmp.xyz..."
Multiwfn $1 > /dev/null << EOF
100
2
2
tmp.xyz
0
q
EOF

if [ ! -f tmp.xyz ]; then
    echo "Error: tmp.xyz file not generated. Multiwfn failed at Step 1."
    exit 1
fi

# Step 2: 创建 Gaussian 优化任务输入文件
echo "Generating Gaussian input file for optimization..."
cat << EOF > gau.gjf
%nproc=64
%mem=40000MB
%chk=gau.chk
$keyword_opt

test

$chg $multi
EOF
awk '{if (NR>2) print }' tmp.xyz >> gau.gjf
cat << EOF >> gau.gjf


EOF
rm tmp.xyz

# Step 3: 执行 Gaussian 优化任务
echo "Running Gaussian optimization..."
$Gaussian < gau.gjf > gau.out

if ! grep -Fq "Normal termination" gau.out; then
    echo "Error: Gaussian optimization task failed. Check gau.out for details."
    exit 1
fi

# Step 4: 创建 Gaussian 单点任务输入文件
echo "Generating Gaussian input file for single point calculation..."
cat << EOF > gau.gjf
%nproc=64
%mem=40000MB
%chk=gau.chk
$keyword_SP geom=allcheck guess=read


EOF

echo "Running Gaussian single point calculation..."
$Gaussian < gau.gjf > gau.out

if ! grep -Fq "Normal termination" gau.out; then
    echo "Error: Gaussian single point task failed. Check gau.out for details."
    exit 1
fi

# Step 5: Formchk 转换
echo "Running formchk to generate fchk file..."
formchk gau.chk > /dev/null

if [ ! -f gau.fchk ]; then
    echo "Error: formchk failed to generate gau.fchk. Check formchk logs."
    exit 1
fi

# Step 6: Multiwfn 生成 RESP 电荷
echo "Running Multiwfn to generate RESP charges..."
Multiwfn gau.fchk -ispecial 1 > /dev/null << EOF
7
18
8
1
gau.out
y
0
0
q
EOF

if [ ! -f gau.chg ]; then
    echo "Error: RESP charge file gau.chg not generated. Multiwfn failed at Step 6."
    exit 1
fi

# Step 7: 重命名 .chg 文件
chgname="${prefix}.chg"
mv gau.chg "$chgname"

if [ ! -f "$chgname" ]; then
    echo "Error: Failed to move gau.chg to $chgname."
    exit 1
fi

echo "Finished! The optimized atomic coordinates with RESP charges (the last column) have been exported to $chgname."
echo "Please properly cite Multiwfn in your publication according to \"How to cite Multiwfn.pdf\" in Multiwfn package."
