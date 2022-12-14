#!/bin/bash
# 安装 jq 和 wget
if [ -f /etc/debian_version ]; then
  sudo apt install jq
  apt install wget
elif [ -f /etc/redhat-release ]; then
  sudo yum -y install jq
  yum -y install wget
else
  # 输出发行版不支持，让用户自己安装 jq、wget
  echo "For unsupported distributions, please check if jq, wget are installed"
  exit;
fi

# URL 解码方法，需要有双引号
urldecode() { local u="${1//+/ }"; printf '%b' "${u//%/\\x}"; }
# 获取版本 JSON。-s 不显示 curl 进度
releasesJson=`curl https://dragonwell-jdk.io/releases.json`
# 安装目录
installDir=/opt/java

# TODO 选择类型 extended、standard

# 获取 version
# .extended 获取 {"version8": "8.13.14"}
# to_entries 转成 [{"key": "version8", "value": "8.13.14"}]
keyValues=`echo $releasesJson | jq '.extended | to_entries'`
# .[] 获取 to_entries 结果 [] 中的内容
# select(.key|test("version.")) 查询 key 为含 version 的 value
versions=`echo $keyValues | jq '.[] | select(.key | test("version")) | .value'`

# 将 versions 转换为数组
declare -a versionArr=($versions)
echo
# 循环显示版本
for (( i=1; i<=${#versionArr[@]}; i++ ))
do
  echo $i. ${versionArr[$i-1]};
done;
# 选择版本
read -p 'the serial number of the version:' selectedNum
echo

# 获取选择的版本去除双引号：https://blog.csdn.net/whatday/article/details/117716490
selectedVersion=`echo ${versionArr[$selectedNum-1]} | sed 's/\"//g'`
# 获取下载版本
downloadVersionNum=`echo $keyValues | jq '.[] | select(.value | (if . == "'$selectedVersion'" then true else false end)) | .key' | tr -cd '[0-9]'`
# 获取下载地址
downloadUrls=`echo $keyValues | jq '.[] | select(.key | test("[a-z]'$downloadVersionNum'$")) | .value | select(test("http"))'`
declare -a downloadUrlArr=($downloadUrls)
# 循环显示下载地址，第一位仍是版本号，不显示
for((i=1; i<=${#downloadUrlArr[@]}; i++))
do
  # “#”贪婪删除左边的匹配，一直到 /，即文件名，再用 tr 将大写转小写：https://blog.csdn.net/Jerry_1126/article/details/83869630
  downloadFileName=`echo ${downloadUrlArr[$i-1]##*/} | tr [A-Z] [a-z]`
  # 如果文件名中含有 windows 则跳过
  if [[ ${downloadFileName} =~ "windows" ]]; then
    continue
  fi

  echo ${i}. $downloadFileName
done;
# 选择下载地址
read -p 'the serial number of the download file:' selectedNum

# 选择的下载地址
downloadUrl=`echo ${downloadUrlArr[$selectedNum-1]} | sed 's/\"//g'`
# 下载文件路径
filePath=`urldecode $installDir/${downloadUrl##*/}`

# 创建安装目录
mkdir -p $installDir
# 删除旧文件
rm -f ${filePath%%.*}*
# 下载文件。-T 为超时时间，-t 为重试次数
wget -T 10 -t 3 $downloadUrl -P $installDir
# 解压 tar.gz
tar -zxvf $filePath -C $installDir
# 根据压缩包获取解压后的文件夹名称：https://unix.stackexchange.com/questions/229504/find-extracted-directory-name-from-tar-file
untarDirName=`tar -ztf $filePath | head -1 | cut -f1 -d'/'`
# 删除压缩文件
rm -f $filePath
# 删除含有 JAVA_HOME 的行
sed -i '/JAVA_HOME/d' /etc/profile
# 设置环境变量
echo "export JAVA_HOME=$installDir/$untarDirName" >> /etc/profile
echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile
source /etc/profile
# 查看版本
java -version
