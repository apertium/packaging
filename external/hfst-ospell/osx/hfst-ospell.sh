install_dep icu
patch_all
export CXX="x86_64-apple-darwin13-clang++-libc++"
export CXXFLAGS="-std=gnu++11 -stdlib=libc++"
export LDFLAGS="-stdlib=libc++"
autoreconf -fi
./configure --host=x86_64-apple-darwin13 --prefix=/opt/osx --disable-static --enable-zhfst --without-libxmlpp --without-tinyxml2
