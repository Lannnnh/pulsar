#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

set -e

PYTHON_VERSIONS=(
   '3.8  3.8.13'
   '3.9  3.9.10'
   '3.10 3.10.2'
)

export MACOSX_DEPLOYMENT_TARGET=11.0
MACOSX_DEPLOYMENT_TARGET_MAJOR=${MACOSX_DEPLOYMENT_TARGET%%.*}

ZLIB_VERSION=1.2.12
OPENSSL_VERSION=1_1_1n
BOOST_VERSION=1.78.0
PROTOBUF_VERSION=3.20.0
ZSTD_VERSION=1.5.2
SNAPPY_VERSION=1.1.3
CURL_VERSION=7.61.0

ROOT_DIR=$(git rev-parse --show-toplevel)
cd "${ROOT_DIR}/pulsar-client-cpp"


# Compile and cache dependencies
CACHE_DIR=~/.pulsar-mac-wheels-cache
mkdir -p $CACHE_DIR

PREFIX=$CACHE_DIR/install

cd $CACHE_DIR

###############################################################################
for line in "${PYTHON_VERSIONS[@]}"; do
    read -r -a PY <<< "$line"
    PYTHON_VERSION=${PY[0]}
    PYTHON_VERSION_LONG=${PY[1]}

    if [ ! -f Python-${PYTHON_VERSION_LONG}/.done ]; then
      echo "Building Python $PYTHON_VERSION_LONG"
      curl -O -L https://www.python.org/ftp/python/${PYTHON_VERSION_LONG}/Python-${PYTHON_VERSION_LONG}.tgz
      tar xfz Python-${PYTHON_VERSION_LONG}.tgz

      PY_PREFIX=$CACHE_DIR/py-$PYTHON_VERSION
      pushd Python-${PYTHON_VERSION_LONG}
          CFLAGS="-fPIC -O3 -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" \
              ./configure --prefix=$PY_PREFIX --enable-shared
          make -j16
          make install

          curl -O -L https://files.pythonhosted.org/packages/27/d6/003e593296a85fd6ed616ed962795b2f87709c3eee2bca4f6d0fe55c6d00/wheel-0.37.1-py2.py3-none-any.whl
          $PY_PREFIX/bin/pip3 install wheel-*.whl

          touch .done
      popd
    else
      echo "Using cached Python $PYTHON_VERSION_LONG"
    fi
done

###############################################################################
if [ ! -f zlib-${ZLIB_VERSION}/.done ]; then
    echo "Building ZLib"
    curl -O -L https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz
    tar xvfz zlib-$ZLIB_VERSION.tar.gz
    pushd zlib-$ZLIB_VERSION
      CFLAGS="-fPIC -O3 -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" ./configure --prefix=$PREFIX
      make -j16
      make install
      touch .done
    popd
else
    echo "Using cached ZLib"
fi

###############################################################################
if [ ! -f openssl-OpenSSL_${OPENSSL_VERSION}/.done ]; then
    echo "Building OpenSSL"
    curl -O -L https://github.com/openssl/openssl/archive/OpenSSL_${OPENSSL_VERSION}.tar.gz
    tar xvfz OpenSSL_${OPENSSL_VERSION}.tar.gz
    pushd openssl-OpenSSL_${OPENSSL_VERSION}
      ./Configure -fPIC -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET} --prefix=$PREFIX no-shared darwin64-arm64-cc
      make -j8
      make install
      touch .done
    popd
else
    echo "Using cached OpenSSL"
fi

###############################################################################
BOOST_VERSION_=${BOOST_VERSION//./_}
for line in "${PYTHON_VERSIONS[@]}"; do
    read -r -a PY <<< "$line"
    PYTHON_VERSION=${PY[0]}
    PYTHON_VERSION_LONG=${PY[1]}

    DIR=boost-src-${BOOST_VERSION}-python-${PYTHON_VERSION}
    if [ ! -f $DIR/.done ]; then
        echo "Building Boost for Py $PYTHON_VERSION"
        curl -O -L https://boostorg.jfrog.io/artifactory/main/release/${BOOST_VERSION}/source/boost_${BOOST_VERSION_}.tar.gz
        tar xfz boost_${BOOST_VERSION_}.tar.gz
        mv boost_${BOOST_VERSION_} $DIR

        PY_PREFIX=$CACHE_DIR/py-$PYTHON_VERSION

        pushd $DIR
          cat <<EOF > user-config.jam
            using python : $PYTHON_VERSION
                    : python3
                    : ${PY_PREFIX}/include/python${PYTHON_VERSION}
                    : ${PY_PREFIX}/lib
                  ;
EOF
          ./bootstrap.sh --with-libraries=python --with-python=python3 --with-python-root=$PY_PREFIX \
                --prefix=$CACHE_DIR/boost-py-$PYTHON_VERSION
          ./b2 address-model=64 cxxflags="-fPIC -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" link=static threading=multi \
                    --user-config=./user-config.jam \
                    variant=release python=${PYTHON_VERSION} \
                    -j16 \
                    install
          touch .done
        popd
    else
        echo "Using cached Boost for Py $PYTHON_VERSION"
    fi

done



###############################################################################
if [ ! -f protobuf-${PROTOBUF_VERSION}/.done ]; then
    echo "Building Protobuf"
    curl -O -L  https://github.com/google/protobuf/releases/download/v${PROTOBUF_VERSION}/protobuf-cpp-${PROTOBUF_VERSION}.tar.gz
    tar xvfz protobuf-cpp-${PROTOBUF_VERSION}.tar.gz
    pushd protobuf-${PROTOBUF_VERSION}
      CXXFLAGS="-fPIC -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" ./configure --prefix=$PREFIX
      make -j16
      make install
      touch .done
    popd
else
    echo "Using cached Protobuf"
fi

###############################################################################
if [ ! -f zstd-${ZSTD_VERSION}/.done ]; then
    echo "Building ZStd"
    curl -O -L https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz
    tar xvfz zstd-${ZSTD_VERSION}.tar.gz
    pushd zstd-${ZSTD_VERSION}
      CFLAGS="-fPIC -O3 -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" PREFIX=$PREFIX make -j16 install
      touch .done
    popd
else
    echo "Using cached ZStd"
fi

###############################################################################
if [ ! -f snappy-${SNAPPY_VERSION}/.done ]; then
    echo "Building Snappy"
    curl -O -L https://github.com/google/snappy/releases/download/${SNAPPY_VERSION}/snappy-${SNAPPY_VERSION}.tar.gz
    tar xvfz snappy-${SNAPPY_VERSION}.tar.gz
    pushd snappy-${SNAPPY_VERSION}
      CXXFLAGS="-fPIC -O3 -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" ./configure --prefix=$PREFIX
      make -j16
      make install
      touch .done
    popd
else
    echo "Using cached Snappy"
fi

###############################################################################
if [ ! -f curl-${CURL_VERSION}/.done ]; then
    echo "Building LibCurl"
    CURL_VERSION_=${CURL_VERSION//./_}
    curl -O -L  https://github.com/curl/curl/releases/download/curl-${CURL_VERSION_}/curl-${CURL_VERSION}.tar.gz
    tar xfz curl-${CURL_VERSION}.tar.gz
    pushd curl-${CURL_VERSION}
      CFLAGS="-fPIC -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" ./configure --with-ssl=$PREFIX \
              --without-nghttp2 --without-libidn2 --prefix=$PREFIX
      make -j16 install
      touch .done
    popd
else
    echo "Using cached LibCurl"
fi

###############################################################################
###############################################################################
###############################################################################
###############################################################################

for line in "${PYTHON_VERSIONS[@]}"; do
    read -r -a PY <<< "$line"
    PYTHON_VERSION=${PY[0]}
    PYTHON_VERSION_LONG=${PY[1]}
    echo '----------------------------------------------------------------------------'
    echo '----------------------------------------------------------------------------'
    echo '----------------------------------------------------------------------------'
    echo "Build wheel for Python $PYTHON_VERSION"

    cd "${ROOT_DIR}/pulsar-client-cpp"

    find . -name CMakeCache.txt | xargs -r rm
    find . -name CMakeFiles | xargs -r rm -rf

    PY_PREFIX=$CACHE_DIR/py-$PYTHON_VERSION
    PY_EXE=$PY_PREFIX/bin/python3

    cmake . \
            -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} \
            -DCMAKE_OSX_SYSROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX${MACOSX_DEPLOYMENT_TARGET_MAJOR}.sdk \
            -DCMAKE_INSTALL_PREFIX=$PREFIX \
            -DCMAKE_INSTALL_LIBDIR=$PREFIX/lib \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_PREFIX_PATH=$PREFIX \
            -DCMAKE_CXX_FLAGS=-I$PREFIX/include \
            -DCMAKE_FIND_FRAMEWORK=$PREFIX \
            -DBoost_INCLUDE_DIR=$CACHE_DIR/boost-py-$PYTHON_VERSION/include \
            -DBoost_LIBRARY_DIRS=$CACHE_DIR/boost-py-$PYTHON_VERSION/lib \
            -DPYTHON_INCLUDE_DIR=$PY_PREFIX/include/python$PYTHON_VERSION \
            -DPYTHON_LIBRARY=$PY_PREFIX/lib/libpython${PYTHON_VERSION}.dylib \
            -DLINK_STATIC=ON \
            -DBUILD_TESTS=OFF \
            -DBUILD_WIRESHARK=OFF \
            -DPROTOC_PATH=$PREFIX/bin/protoc

    make clean
    make _pulsar -j16

    cd python
    $PY_EXE setup.py bdist_wheel
done