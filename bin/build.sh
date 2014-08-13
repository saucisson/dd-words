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
  make > /dev/null 2>&1
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

# Install redis and hiredis:
sudo apt-get install libhiredis-dev redis-server

# Install data files:
if [ ! -d words ]
then
  mkdir words
  cd words
  rm -f *
  max_size=0
  for language in en fr # Add other languages...
  do
    echo "Generating dictionary for ${language}..."
    sudo apt-get install -y aspell-${language}
    aspell -d ${language} dump master | \
      aspell -l ${language} expand | \
      tr " " "\n" | \
      tr "A-Z" "a-z" | \
      sort --unique >> ${language} 2> /dev/null
    size=$(cat ${language} | wc --max-line-length)
    if [ ${size} -gt ${max_size} ]
    then
      max_size=${size}
    fi
  done
#  echo ${max_size} > max-size
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
echo
echo "Running ddd-fixed..."
time ./ddd-fixed words/*
echo
echo "Running sdd-fixed..."
time ./sdd-fixed words/*
echo
echo "Running ddd-variable..."
time ./ddd-variable words/*
echo
echo "Running redis-simple..."
time ./redis-simple words/*
echo
echo "Running redis-pipeline..."
time ./redis-pipeline words/*
echo
echo "Running redis-update-simple..."
time ./redis-update-simple words/*
echo
echo "Running redis-update-pipeline..."
time ./redis-update-pipeline words/*
