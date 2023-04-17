CORE_GIT=https://github.com/minetest/minetest
CORE_BRANCH=master
CORE_NAME=minetest
GAME_GIT=https://github.com/minetest/minetest_game
GAME_BRANCH=master
GAME_NAME=minetest_game

ogg_version=1.3.5
openal_version=1.23.0
vorbis_version=1.3.7
curl_version=8.0.1
gettext_version=0.20.2
freetype_version=2.12.1
sqlite3_version=3.41.2
luajit_version=20230221
leveldb_version=1.23
zlib_version=1.2.13
zstd_version=1.5.5

download () {
	local url=$1
	local filename=$2
	[ -z "$filename" ] && filename=${url##*/}
	local foldername=${filename%%[.-]*}
	local extract=${3:-unzip}

	[ -d "./$foldername" ] && return 0
	wget "$url" -c -O "./$filename"
	if [ "$extract" = "unzip" ]; then
		unzip -o "$filename" -d "$foldername"
	elif [ "$extract" = "unzip_nofolder" ]; then
		unzip -o "$filename"
	else
		return 1
	fi
}

# sets $sourcedir
get_sources () {
	if [ -n "$EXISTING_MINETEST_DIR" ]; then
		sourcedir="$( cd "$EXISTING_MINETEST_DIR" && pwd )"
		return
	fi
	cd $builddir
	sourcedir=$PWD/$CORE_NAME
	[ -d $CORE_NAME ] && { pushd $CORE_NAME; git pull --ff-only; popd; } || \
		git clone -b $CORE_BRANCH $CORE_GIT $CORE_NAME
	if [ -z "$NO_MINETEST_GAME" ]; then
		cd $sourcedir
		[ -d games/$GAME_NAME ] && { pushd games/$GAME_NAME; git pull --ff-only; popd; } || \
			git clone -b $GAME_BRANCH $GAME_GIT games/$GAME_NAME
	fi
}

# sets $runtime_dlls
find_runtime_dlls () {
	local triple=$1
	# Try to find runtime DLLs in various paths (varies by distribution, sigh)
	local tmp=$(dirname "$(command -v $compiler)")/..
	runtime_dlls=
	for name in lib{gcc_,stdc++-,winpthread-}'*'.dll; do
		for dir in $tmp/$triple/{bin,lib} $tmp/lib/gcc/$triple/*; do
			[ -d "$dir" ] || continue
			local file=$(echo $dir/$name)
			[ -f "$file" ] && { runtime_dlls+="$file;"; break; }
		done
	done
	if [ -z "$runtime_dlls" ]; then
		echo "The compiler runtime DLLs could not be found, they might be missing in the final package."
	else
		echo "Found DLLs: $runtime_dlls"
	fi
}

add_cmake_libs () {
	local irr_dlls=$(echo $libdir/irrlicht/lib/*.dll | tr ' ' ';')
	local vorbis_dlls=$(echo $libdir/libvorbis/bin/libvorbis{,file}-*.dll | tr ' ' ';')
	local gettext_dlls=$(echo $libdir/gettext/bin/lib{intl,iconv}-*.dll | tr ' ' ';')

	cmake_args+=(
		-DCMAKE_PREFIX_PATH=$libdir/irrlicht
		-DIRRLICHT_DLL="$irr_dlls"

		-DZLIB_INCLUDE_DIR=$libdir/zlib/include
		-DZLIB_LIBRARY=$libdir/zlib/lib/libz.dll.a
		-DZLIB_DLL=$libdir/zlib/bin/zlib1.dll

		-DZSTD_INCLUDE_DIR=$libdir/zstd/include
		-DZSTD_LIBRARY=$libdir/zstd/lib/libzstd.dll.a
		-DZSTD_DLL=$libdir/zstd/bin/libzstd.dll

		-DLUA_INCLUDE_DIR=$libdir/luajit/include
		-DLUA_LIBRARY=$libdir/luajit/libluajit.a

		-DOGG_INCLUDE_DIR=$libdir/libogg/include
		-DOGG_LIBRARY=$libdir/libogg/lib/libogg.dll.a
		-DOGG_DLL=$libdir/libogg/bin/libogg-0.dll

		-DVORBIS_INCLUDE_DIR=$libdir/libvorbis/include
		-DVORBIS_LIBRARY=$libdir/libvorbis/lib/libvorbis.dll.a
		-DVORBIS_DLL="$vorbis_dlls"
		-DVORBISFILE_LIBRARY=$libdir/libvorbis/lib/libvorbisfile.dll.a

		-DOPENAL_INCLUDE_DIR=$libdir/openal/include/AL
		-DOPENAL_LIBRARY=$libdir/openal/lib/libOpenAL32.dll.a
		-DOPENAL_DLL=$libdir/openal/bin/OpenAL32.dll

		-DCURL_DLL=$libdir/curl/bin/libcurl-4.dll
		-DCURL_INCLUDE_DIR=$libdir/curl/include
		-DCURL_LIBRARY=$libdir/curl/lib/libcurl.dll.a

		-DGETTEXT_MSGFMT=`command -v msgfmt`
		-DGETTEXT_DLL="$gettext_dlls"
		-DGETTEXT_INCLUDE_DIR=$libdir/gettext/include
		-DGETTEXT_LIBRARY=$libdir/gettext/lib/libintl.dll.a

		-DFREETYPE_INCLUDE_DIR_freetype2=$libdir/freetype/include/freetype2
		-DFREETYPE_INCLUDE_DIR_ft2build=$libdir/freetype/include/freetype2
		-DFREETYPE_LIBRARY=$libdir/freetype/lib/libfreetype.dll.a
		-DFREETYPE_DLL=$libdir/freetype/bin/libfreetype-6.dll

		-DSQLITE3_INCLUDE_DIR=$libdir/sqlite3/include
		-DSQLITE3_LIBRARY=$libdir/sqlite3/lib/libsqlite3.dll.a
		-DSQLITE3_DLL=$libdir/sqlite3/bin/libsqlite3-0.dll

		-DLEVELDB_INCLUDE_DIR=$libdir/leveldb/include
		-DLEVELDB_LIBRARY=$libdir/leveldb/lib/libleveldb.dll.a
		-DLEVELDB_DLL=$libdir/leveldb/bin/libleveldb.dll
	)
}
