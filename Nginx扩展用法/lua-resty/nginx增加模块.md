1. 首先安装luajit2 --> <https://github.com/openresty/luajit2/releases>


    tar zxf luajit2-2.1-20200102.tar.gz && cd luajit2-2.1-20200102
    make && make install PREFIX=/usr/local/luajit2-2.1
    cd /usr/local/ && ln -sf luajit2-2.1 luajit2
    tee /etc/profile.d/luajit2.sh <<-EOF
    export LUAJIT_LIB=/usr/local/luajit2/lib
    export LUAJIT_INC=/usr/local/luajit2/include/luajit-2.1
    EOF
    source /etc/profile
    echo "/usr/local/LuaJIT/lib" >> /etc/ld.so.conf
    ldconfig