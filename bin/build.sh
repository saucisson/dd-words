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
  git checkout variable_length
  cd ..
else
  echo "Cloning libsdd..."
  git clone https://github.com/ahamez/libsdd.git
  cd libsdd
  git checkout variable_length
  cd ..
  sudo apt-get install -y libboost-system-dev
fi

if [ -d cereal ]
then
  echo "Updating cereal..."
  cd cereal
  git pull
  cd ..
else
  echo "Cloning cereal..."
  git clone https://github.com/USCiLab/cereal.git
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
  for language in bg br cs cy da de en eo es fr ga hr hsb is nl pl ro sk sl sv
    # Add other languages... avoid it hu et lt
#  for language in en fr
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
mkdir -p gen/json
mkdir -p gen/height

echo "Compiling set/ddd-fixed..."
g++ -O3 -std=c++11 -DNDEBUG \
    src/set/ddd-fixed.cc \
    -I ddd/src \
    -L ddd/src \
    -lDDD \
    -o gen/set/ddd-fixed
echo "Compiling set/ddd-variable..."
g++ -O3 -std=c++11 -DNDEBUG \
    src/set/ddd-variable.cc \
    -I ddd/src \
    -L ddd/src \
    -lDDD \
    -o gen/set/ddd-variable
echo "Compiling set/sdd-fixed..."
g++ -O3 -std=c++11 -DNDEBUG \
    src/set/sdd-fixed.cc \
    -I libsdd/ \
    -lboost_system \
    -o gen/set/sdd-fixed
echo "Compiling set/sdd-variable..."
g++ -O3 -std=c++11 -DNDEBUG \
    src/set/sdd-variable.cc \
    -I libsdd/ \
    -lboost_system \
    -o gen/set/sdd-variable
echo "Compiling set/sdd-stream-fixed..."
g++ -O3 -std=c++11 -DNDEBUG \
    src/set/sdd-stream-fixed.cc \
    -I libsdd/ \
    -lboost_system \
    -o gen/set/sdd-stream-fixed
echo "Compiling set/sdd-stream-variable..."
g++ -O3 -std=c++11 -DNDEBUG \
    src/set/sdd-stream-variable.cc \
    -I libsdd/ \
    -lboost_system \
    -o gen/set/sdd-stream-variable
echo "Compiling set/sdd-hierarchy..."
g++ -O3 -std=c++11 -DNDEBUG \
    src/set/sdd-hierarchy.cc \
    -I libsdd/ \
    -lboost_system \
    -o gen/set/sdd-hierarchy
echo "Compiling set/redis-simple..."
g++ -O3 -std=c++11 -DNDEBUG \
    src/set/redis-simple.cc \
    -lhiredis \
    -o gen/set/redis-simple
echo "Compiling set/redis-pipeline..."
g++ -O3 -std=c++11 -DNDEBUG \
    src/set/redis-pipeline.cc \
    -lhiredis \
    -o gen/set/redis-pipeline
echo "Compiling set/redis-update-simple..."
g++ -O3 -std=c++11 -DNDEBUG \
    src/set/redis-update-simple.cc \
    -lhiredis \
    -o gen/set/redis-update-simple
echo "Compiling set/redis-update-pipeline..."
g++ -O3 -std=c++11 -DNDEBUG \
    src/set/redis-update-pipeline.cc \
    -lhiredis \
    -o gen/set/redis-update-pipeline
echo "Copying json/mongo-simple..."
cp src/json/mongo-simple.lua \
   gen/json/mongo-simple
chmod a+x gen/json/mongo-simple
echo "Copying json/mongo-batch..."
cp src/json/mongo-batch.lua \
   gen/json/mongo-batch
chmod a+x gen/json/mongo-batch
echo "Compiling json/sdd..."
g++ -O3 -std=c++11 -DNDEBUG \
    src/json/sdd.cc \
    -I libsdd/ \
    -I cereal/include \
    -lboost_system -lboost_context -lboost_coroutine \
    -o gen/json/sdd
echo "Compiling height/ddd-value..."
g++ -O3 -std=c++11 -DNDEBUG \
    src/height/ddd-value.cc \
    -I ddd/src \
    -L ddd/src \
    -lDDD \
    -o gen/height/ddd-value
echo "Compiling height/ddd-set"
g++ -O3 -std=c++11 -DNDEBUG \
    src/height/ddd-set.cc \
    -I ddd/src \
    -L ddd/src \
    -lDDD \
    -o gen/height/ddd-set
echo "Compiling height/sdd..."
g++ -O3 -std=c++11 -DNDEBUG \
    src/height/sdd.cc \
    -I libsdd/ \
    -I cereal/include \
    -lboost_system -lboost_context -lboost_coroutine \
    -o gen/height/sdd

# Run:
#TIMEFORMAT='%lE'
#for binary in gen/set/*
#do
#  echo
#  echo "Running ${binary}..."
#  time ./${binary} words/*
#done
