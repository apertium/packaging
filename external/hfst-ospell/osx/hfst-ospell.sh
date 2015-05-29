patch_all
export CXX="x86_64-apple-darwin12-clang++-libc++"
export CXXFLAGS="-std=gnu++11 -stdlib=libc++"
export LDFLAGS="-stdlib=libc++"
autoreconf -fi
./configure --host=x86_64-apple-darwin12 --prefix=/opt/osx
