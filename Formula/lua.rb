class Lua < Formula
  desc "Powerful, lightweight programming language"
  homepage "https://www.lua.org/"
  url "https://www.lua.org/ftp/lua-5.3.5.tar.gz"
  sha256 "0c2eed3f960446e1a3e4b9a1ca2f3ff893b6ce41942cf54d5dd59ab4b3b058ac"

  bottle do
    cellar :any
    sha256 "e4878844eb5b248ac72df3fead9d5dac8b432ad4385c1956d8577884fb2520c1" => :mojave
    sha256 "0519eedf38f18d868842cead8c66ea1784ead938e0eed940d89e7d50c8259884" => :high_sierra
    sha256 "e93b77f260956a5f16ff0df19c8bdaa6047ff6fe7cde806f65624c728db63ae9" => :sierra
    sha256 "79caa0554afffb84b0827f50e65dc57d7e7d34ff83db76341427ed5293b3a21c" => :el_capitan
  end

  option "without-luarocks", "Don't build with Luarocks support embedded"

  # Be sure to build a dylib, or else runtime modules will pull in another static copy of liblua = crashy
  # See: https://github.com/Homebrew/legacy-homebrew/pull/5043
  # ***Update me with each version bump!***
  patch :DATA

  resource "luarocks" do
    url "https://luarocks.org/releases/luarocks-2.4.4.tar.gz"
    sha256 "3938df33de33752ff2c526e604410af3dceb4b7ff06a770bc4a240de80a1f934"
  end

  def install
    # Subtitute formula prefix in `src/Makefile` for install name (dylib ID).
    # Use our CC/CFLAGS to compile.
    inreplace "src/Makefile" do |s|
      s.gsub! "@LUA_PREFIX@", prefix
      s.remove_make_var! "CC"
      s.change_make_var! "CFLAGS", "#{ENV.cflags} -DLUA_COMPAT_5_2 $(SYSCFLAGS) $(MYCFLAGS)"
      s.change_make_var! "MYLDFLAGS", ENV.ldflags
    end

    # Fix path in the config header
    inreplace "src/luaconf.h", "/usr/local", HOMEBREW_PREFIX

    # We ship our own pkg-config file as Lua no longer provide them upstream.
    system "make", "macosx", "INSTALL_TOP=#{prefix}", "INSTALL_INC=#{include}/lua", "INSTALL_MAN=#{man1}"
    system "make", "install", "INSTALL_TOP=#{prefix}", "INSTALL_INC=#{include}/lua", "INSTALL_MAN=#{man1}"
    (lib/"pkgconfig/lua.pc").write pc_file

    # Fix some software potentially hunting for different pc names.
    bin.install_symlink "lua" => "lua5.3"
    bin.install_symlink "lua" => "lua-5.3"
    bin.install_symlink "luac" => "luac5.3"
    bin.install_symlink "luac" => "luac-5.3"
    (include/"lua5.3").install_symlink Dir[include/"lua/*"]
    lib.install_symlink "liblua.5.3.dylib" => "liblua5.3.dylib"
    (lib/"pkgconfig").install_symlink "lua.pc" => "lua5.3.pc"
    (lib/"pkgconfig").install_symlink "lua.pc" => "lua-5.3.pc"

    # This resource must be handled after the main install, since there's a lua dep.
    # Keeping it in install rather than postinstall means we can bottle.
    if build.with? "luarocks"
      resource("luarocks").stage do
        ENV.prepend_path "PATH", bin

        system "./configure", "--prefix=#{libexec}", "--rocks-tree=#{HOMEBREW_PREFIX}",
                              "--sysconfdir=#{etc}/luarocks53", "--with-lua=#{prefix}",
                              "--lua-version=5.3", "--versioned-rocks-dir"
        system "make", "build"
        system "make", "install"

        (pkgshare/"5.3/luarocks").install_symlink Dir["#{libexec}/share/lua/5.3/luarocks/*"]
        bin.install_symlink libexec/"bin/luarocks-5.3"
        bin.install_symlink libexec/"bin/luarocks-admin-5.3"
        bin.install_symlink libexec/"bin/luarocks"
        bin.install_symlink libexec/"bin/luarocks-admin"

        # This block ensures luarock exec scripts don't break across updates.
        inreplace libexec/"share/lua/5.3/luarocks/site_config.lua" do |s|
          s.gsub! libexec, opt_libexec
          s.gsub! include, HOMEBREW_PREFIX/"include"
          s.gsub! lib, HOMEBREW_PREFIX/"lib"
          s.gsub! bin, HOMEBREW_PREFIX/"bin"
        end
      end
    end
  end

  def pc_file; <<~EOS
    V= 5.3
    R= #{version}
    prefix=#{HOMEBREW_PREFIX}
    INSTALL_BIN= ${prefix}/bin
    INSTALL_INC= ${prefix}/include/lua
    INSTALL_LIB= ${prefix}/lib
    INSTALL_MAN= ${prefix}/share/man/man1
    INSTALL_LMOD= ${prefix}/share/lua/${V}
    INSTALL_CMOD= ${prefix}/lib/lua/${V}
    exec_prefix=${prefix}
    libdir=${exec_prefix}/lib
    includedir=${prefix}/include/lua

    Name: Lua
    Description: An Extensible Extension Language
    Version: #{version}
    Requires:
    Libs: -L${libdir} -llua -lm
    Cflags: -I${includedir}
  EOS
  end

  def caveats; <<~EOS
    Please be aware due to the way Luarocks is designed any binaries installed
    via Luarocks-5.3 AND 5.1 will overwrite each other in #{HOMEBREW_PREFIX}/bin.

    This is, for now, unavoidable. If this is troublesome for you, you can build
    rocks with the `--tree=` command to a special, non-conflicting location and
    then add that to your `$PATH`.
  EOS
  end

  test do
    system "#{bin}/lua", "-e", "print ('Ducks are cool')"

    if File.exist?(bin/"luarocks-5.3")
      (testpath/"luarocks").mkpath
      system bin/"luarocks-5.3", "install", "moonscript", "--tree=#{testpath}/luarocks"
      assert_predicate testpath/"luarocks/bin/moon", :exist?
    end
  end
end

__END__
diff --git a/Makefile b/Makefile
index 7fa91c8..a825198 100644
--- a/Makefile
+++ b/Makefile
@@ -41,7 +41,7 @@ PLATS= aix bsd c89 freebsd generic linux macosx mingw posix solaris
 # What to install.
 TO_BIN= lua luac
 TO_INC= lua.h luaconf.h lualib.h lauxlib.h lua.hpp
-TO_LIB= liblua.a
+TO_LIB= liblua.5.3.5.dylib
 TO_MAN= lua.1 luac.1

 # Lua version and release.
@@ -63,6 +63,8 @@ install: dummy
	cd src && $(INSTALL_DATA) $(TO_INC) $(INSTALL_INC)
	cd src && $(INSTALL_DATA) $(TO_LIB) $(INSTALL_LIB)
	cd doc && $(INSTALL_DATA) $(TO_MAN) $(INSTALL_MAN)
+	ln -s -f liblua.5.3.5.dylib $(INSTALL_LIB)/liblua.5.3.dylib
+	ln -s -f liblua.5.3.dylib $(INSTALL_LIB)/liblua.dylib

 uninstall:
	cd src && cd $(INSTALL_BIN) && $(RM) $(TO_BIN)
diff --git a/src/Makefile b/src/Makefile
index 2e7a412..d0c4898 100644
--- a/src/Makefile
+++ b/src/Makefile
@@ -28,7 +28,7 @@ MYOBJS=

 PLATS= aix bsd c89 freebsd generic linux macosx mingw posix solaris

-LUA_A=	liblua.a
+LUA_A=	liblua.5.3.5.dylib
 CORE_O=	lapi.o lcode.o lctype.o ldebug.o ldo.o ldump.o lfunc.o lgc.o llex.o \
	lmem.o lobject.o lopcodes.o lparser.o lstate.o lstring.o ltable.o \
	ltm.o lundump.o lvm.o lzio.o
@@ -56,11 +56,12 @@ o:	$(ALL_O)
 a:	$(ALL_A)

 $(LUA_A): $(BASE_O)
-	$(AR) $@ $(BASE_O)
-	$(RANLIB) $@
+	$(CC) -dynamiclib -install_name @LUA_PREFIX@/lib/liblua.5.3.dylib \
+		-compatibility_version 5.3 -current_version 5.3.5 \
+		-o liblua.5.3.5.dylib $^

 $(LUA_T): $(LUA_O) $(LUA_A)
-	$(CC) -o $@ $(LDFLAGS) $(LUA_O) $(LUA_A) $(LIBS)
+	$(CC) -fno-common $(MYLDFLAGS) -o $@ $(LUA_O) $(LUA_A) -L. -llua.5.3.5 $(LIBS)

 $(LUAC_T): $(LUAC_O) $(LUA_A)
	$(CC) -o $@ $(LDFLAGS) $(LUAC_O) $(LUA_A) $(LIBS)
@@ -110,7 +111,7 @@ linux:
	$(MAKE) $(ALL) SYSCFLAGS="-DLUA_USE_LINUX" SYSLIBS="-Wl,-E -ldl -lreadline"

 macosx:
-	$(MAKE) $(ALL) SYSCFLAGS="-DLUA_USE_MACOSX" SYSLIBS="-lreadline"
+	$(MAKE) $(ALL) SYSCFLAGS="-DLUA_USE_MACOSX -fno-common" SYSLIBS="-lreadline"

 mingw:
	$(MAKE) "LUA_A=lua53.dll" "LUA_T=lua.exe" \
