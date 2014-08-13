#! /bin/bash

# Install libDDD:
if [ ! -d ddd ]
then
  curl http://move.lip6.fr/software/DDD/download/ddd-1.8.1.tar.gz \
       -o ddd.tar.gz
  mkdir ddd
  tar xf ddd.tar.gz -C ddd --strip-components=1
  cd ddd
  ./configure
  make
  cd ..
  rm ddd.tar.gz
fi

# Install libSDD:
if [ -d libsdd ]
then
  cd libsdd
  git pull
  cd ..
else
  git clone https://github.com/ahamez/libsdd.git
  sudo apt-get install -y libboost-system-dev
fi

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
  echo ${max_size} > max-size
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

# Run:
max_size=$(cat words/max-size)
echo "Running ddd-fixed..."
time ./ddd-fixed ${max_size} words/*
echo "Running sdd-fixed..."
time ./sdd-fixed ${max_size} words/*
echo "Running ddd-variable..."
time ./ddd-variable words/*
