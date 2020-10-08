#### 操作系统安装luajit2

---
- 安装脚本如下
```  
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
```
- 获取安装包地址
  
  > https://github.com/openresty/luajit2/releases  

#### 安装nginx及module
---
- 安装脚本
```
// 解压 lua-nginx-module-0.10.14.tar.gz --> /data/softsrc/lua-nginx-module-0.10.14
// 解压 ngx_devel_kit-0.3.1.tar.gz --> /data/softsrc/ngx_devel_kit-0.3.1
// 解压 nginx-1.16.1.tar.gz --> nginx-1.18.0
tar zxf nginx-1.18.0.tar.gz && cd nginx-1.18.0
./configure \
--user=www \
--group=www \
--prefix=/usr/local/nginx-1.16.1 \
--with-http_realip_module \
--with-http_ssl_module \
--with-http_stub_status_module \
--with-http_gzip_static_module \
--with-pcre \
--with-stream \
--with-ld-opt="-Wl,-rpath,/usr/local/luajit2/lib" \
--add-module=/data/softsrc/ngx_devel_kit-0.3.1 \
--add-module=/data/softsrc/lua-nginx-module-0.10.14 && make -j8 && make install
```
- 获取安装包地址
  > https://github.com/openresty/lua-nginx-module/releases
  > https://github.com/vision5/ngx_devel_kit/releases
  > http://nginx.org/download/nginx-1.18.0.tar.gz

#### Nginx集成 lua-resty 模块
---
- 下载各种模块包
```
cd /usr/local/nginx-1.18.0/conf/
git clone https://github.com/openresty/lua-resty-redis.git
git clone https://github.com/doujiang24/lua-resty-kafka
```

- 编译安装cjson
```
cd /data/apps/
git clone https://github.com/openresty/lua-cjson.git && cd lua-cjson
make LUA_INCLUDE_DIR=/usr/local/luajit2/include/luajit-2.1
mkdir /usr/local/nginx/conf/cpath
cp cjson.so /usr/local/nginx/conf/cpath
```

- 配置nginx.conf
> lua_shared_dict shared_data 10m;  
> lua_package_path "/usr/local/nginx/conf/lua-resty-kafka/lib/?.lua;/usr/local/nginx/conf/lua-resty-redis/lib/?.lua;;";  
> lua_package_cpath "/usr/local/nginx/conf/cpath/?.so;;";

- 配置nginx.conf 添加脚本路径
> lua_code_cache off;    //调试打开  
> log_by_lua_file /usr/local/nginx/conf/lua/log2kafka.lua;  
> access_by_lua_file /usr/local/nginx/conf/lua/access_limit.lua;