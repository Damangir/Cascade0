real_path () {
while [ "${1:0:1}" = "-" ]
do
  shift
done
ABSPATH=$(cd "$(dirname "$@")"; pwd)
echo $ABSPATH
}
$(command -v readlink) -f ~ &>/dev/null || alias readlink='real_path'
