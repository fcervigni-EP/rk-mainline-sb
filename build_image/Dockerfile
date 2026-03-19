FROM dockcross/linux-arm64

RUN apt-get update && \
    apt-get install -y \
        build-essential \
        git \
        wget \
        bc \
        bison \
        flex \
        libssl-dev \
        device-tree-compiler \
        make \
        libsdl1.2-dev \
        libsdl2-dev \
        libncurses-dev \
        u-boot-tools

#RUN wget https://releases.linaro.org/components/toolchain/binaries/latest-7/arm-linux-gnueabihf/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf.tar.xz && \
#    tar xvf gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf.tar.xz -C /opt/ && \
#    rm gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf.tar.xz
#ENV PATH="/opt/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf/bin:${PATH}"

# RUN ln -s /usr/bin/python2.7 /usr/bin/python2

WORKDIR /workspace

CMD ["/bin/bash"]