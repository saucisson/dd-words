#! /bin/bash

# Install libDDD:
if [ ! -d ddd ]
then
  echo "Building libDDD..."
  curl -s http://move.lip6.fr/software/DDD/download/ddd-1.8.1.tar.gz \
       -o ddd.tar.gz
  mkdir ddd
  tar xf ddd.tar.gz -C ddd --strip-components=1
  cd ddd
  ./configure > /dev/null 2>&1
  make -j 4 > /dev/null 2>&1
  cd ..
  rm ddd.tar.gz
fi

# Install libSDD:
if [ -d libsdd ]
then
  echo "Updating libsdd..."
  cd libsdd
  git pull
  cd ..
else
  echo "Cloning libsdd..."
  git clone https://github.com/ahamez/libsdd.git
  sudo apt-get install -y libboost-system-dev
fi

# Install JSON-Spirit:
sudo apt-get install -y libjson-spirit-dev

# Install MongoDB:
sudo apt-get install -y mongodb-server mongodb-dev libmongo-client-dev
#sudo apt-get install -y luarocks
if [ "$(luarocks list | grep 'dkjson')" = "" ]
then
  luarocks install dkjson
fi
if [ "$(luarocks list | grep 'luamongo')" = "" ]
then
  luarocks install "https://raw.githubusercontent.com/moai/luamongo/master/rockspec/luamongo-scm-0.rockspec"
fi

# Install redis and hiredis:
sudo apt-get install libhiredis-dev redis-server

# Install word files:
if [ ! -d words ]
then
  mkdir words
  cd words
#  for language in bg br cs cy da de en eo es fr ga hr hsb is nl pl ro sk sl sv
    # Add other languages... avoid it hu et lt
  for language in en fr
  do
    echo "Generating dictionary for ${language}..."
    sudo apt-get install -y aspell-${language}
    aspell -d ${language} dump master | \
      aspell -l ${language} expand | \
      tr " " "\n" >> ${language} # 2> /dev/null
      #tr "A-Z" "a-z" | \
      #sort --unique \
  done
  cd ..
fi

# Compile:
mkdir -p gen/set

echo "Compiling ddd-fixed..."
g++ -O3 -std=c++11 \
    src/set/ddd-fixed.cc \
    -I ddd/src \
    -L ddd/src \
    -lDDD \
    -o gen/set/ddd-fixed
echo "Compiling ddd-variable..."
g++ -O3 -std=c++11 \
    src/set/ddd-variable.cc \
    -I ddd/src \
    -L ddd/src \
    -lDDD \
    -o gen/set/ddd-variable
echo "Compiling sdd-fixed..."
g++ -O3 -std=c++11 \
    src/set/sdd-fixed.cc \
    -I libsdd/ \
    -lboost_system \
    -o gen/set/sdd-fixed
echo "Compiling redis-simple..."
g++ -O3 -std=c++11 \
    src/set/redis-simple.cc \
    -lhiredis \
    -o gen/set/redis-simple
echo "Compiling redis-pipeline..."
g++ -O3 -std=c++11 \
    src/set/redis-pipeline.cc \
    -lhiredis \
    -o gen/set/redis-pipeline
echo "Compiling redis-update-simple..."
g++ -O3 -std=c++11 \
    src/set/redis-update-simple.cc \
    -lhiredis \
    -o gen/set/redis-update-simple
echo "Compiling redis-update-pipeline..."
g++ -O3 -std=c++11 \
    src/set/redis-update-pipeline.cc \
    -lhiredis \
    -o gen/set/redis-update-pipeline
echo "Copying mongo-simple..."
cp src/set/mongo-simple.lua \
   gen/set/mongo-simple
chmod a+x gen/set/mongo-simple
echo "Copying mongo-batch..."
cp src/set/mongo-batch.lua \
   gen/set/mongo-batch
chmod a+x gen/set/mongo-batch

# Run:
TIMEFORMAT='%lE'
for binary in gen/set/*
do
  echo
  echo "Running ${binary}..."
  time ./${binary} words/*
done
