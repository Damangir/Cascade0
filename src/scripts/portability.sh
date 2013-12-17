real_path () {
while [ "${1:0:1}" = "-" ]
do
  shift
done
ABSPATH=$(cd "$(dirname "$@")"; pwd)
echo $ABSPATH
}
which realpath || alias realpath='real_path'
