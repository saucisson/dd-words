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
luarocks install "https://raw.githubusercontent.com/moai/luamongo/master/rockspec/luamongo-scm-0.rockspec"

# Install redis and hiredis:
sudo apt-get install libhiredis-dev redis-server

# Install word files:
if [ ! -d words ]
then
  mkdir words
  cd words
  rm -f *
  max_size=0
  for language in bg br cs cy da de en eo es fr ga hr hsb is nl pl ro sk sl sv
    # Add other languages... avoid it hu et lt
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

if [ ! -d json ]
then
  mkdir json
  cd json
  echo "Downloading small JSON..."
  curl -s \
    https://raw.githubusercontent.com/sanSS/json-bechmarks/master/data/small-dict.json \
    -o json/small.json
  echo "Downloading medium JSON..."
  curl -s \
    https://raw.githubusercontent.com/sanSS/json-bechmarks/master/data/medium-dict.json \
    -o medium.json
  echo "Downloading large JSON..."
  curl -s \
    https://raw.githubusercontent.com/sanSS/json-bechmarks/master/data/large-dict.json \
    -o large.json
  echo "Downloading real and huge JSON..."
  curl -s \
    https://raw.githubusercontent.com/zemirco/sf-city-lots-json/master/citylots.json \
    -o real.json
  cd ..
fi

# Compile:
echo "Compiling ddd-fixed..."
g++ -O3 -std=c++11 \
    src/ddd-fixed.cc \
    -I ddd/src \
    -L ddd/src \
    -lDDD \
    -o ddd-fixed

echo "Compiling ddd-variable..."
g++ -O3 -std=c++11 \
    src/ddd-variable.cc \
    -I ddd/src \
    -L ddd/src \
    -lDDD \
    -o ddd-variable

echo "Compiling sdd-fixed..."
g++ -O3 -std=c++11 \
    src/sdd-fixed.cc \
    -I libsdd/ \
    -lboost_system \
    -o sdd-fixed

echo "Compiling redis-simple..."
g++ -O3 -std=c++11 \
    src/redis-simple.cc \
    -lhiredis \
    -o redis-simple
echo "Compiling redis-pipeline..."
g++ -O3 -std=c++11 \
    src/redis-pipeline.cc \
    -lhiredis \
    -o redis-pipeline
echo "Compiling redis-update-simple..."
g++ -O3 -std=c++11 \
    src/redis-update-simple.cc \
    -lhiredis \
    -o redis-update-simple
echo "Compiling redis-update-pipeline..."
g++ -O3 -std=c++11 \
    src/redis-update-pipeline.cc \
    -lhiredis \
    -o redis-update-pipeline

# Run:
TIMEFORMAT='%lE'
for binary in sdd-fixed redis-pipeline
do
  echo
  echo "Running ${binary}..."
  ./${binary} words/*
done
