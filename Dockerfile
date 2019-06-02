FROM resin/rpi-raspbian:jessie  

RUN apt-get update && apt-get install -y --no-install-recommends \
 pkg-config wget zip g++ zlib1g-dev unzip \
 oracle-java8-jdk

RUN update-alternatives --config java

RUN apt-get install -y --no-install-recommends \
 python-pip python-numpy swig python-dev

RUN pip install wheel

RUN apt-get install -y --no-install-recommends \  
 gcc-4.8 g++-4.8

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.8 100
RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-4.8 100

RUN mkdir tensorflow
WORKDIR tensorflow

# Skipping Swap space
RUN wget https://github.com/bazelbuild/bazel/releases/download/0.11.0/bazel-0.11.0-dist.zip
RUN unzip -d bazel bazel-0.11.0-dist.zip
WORKDIR  bazel
#RUN echo "PWD is: $PWD"
RUN echo "$(ls ./scripts/bootstrap)"
RUN sed -i   '/.*-enc/ s/$/ -J-Xmx500M/'  ./scripts/bootstrap/compile.sh

RUN echo "$(ls)"
RUN ./compile.sh 2>&1 | tee buildLog.out
RUN cp output/bazel /usr/local/bin/bazel

# Tensorflow configuration
RUN apt-get update && apt-get install --fix-missing -y git
RUN  git clone --recurse-submodules https://github.com/tensorflow/tensorflow.git
WORKDIR tensorflow
RUN echo "PWD is: $PWD"

RUN git checkout v1.6.0
RUN grep -Rl 'lib64' | xargs sed -i 's/lib64/lib/g'
RUN sed -i   '/#define IS_MOBILE_PLATFORM/d' tensorflow/core/platform/platform.h
RUN sed -i  "s/f3a22f35b044/d781c1de9834/" tensorflow/workspace.bzl
RUN sed -i  "s/ca7beac153d4059c02c8fc59816c82d54ea47fe58365e8aded4082ded0b820c4/a34b208da6ec18fa8da963369e166e4a368612c14d956dd2f9d7072904675d9b/" tensorflow/workspace.bzl

RUN apt-get install -y patch libeigen3-dev 
RUN ./configure
RUN bazel build -c opt --copt="-mfpu=neon-vfpv4" \
   --copt="-funsafe-math-optimizations" \
   --copt="-ftree-vectorize" \
   --copt="-fomit-frame-pointer" \
   --local_resources 1024,1.0,1.0 \
   --verbose_failures tensorflow/tools/pip_package:build_pip_package \
   2>&1 | tee buildLog.out

RUN bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg
