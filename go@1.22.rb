class GoAT122 < Formula
    desc "Go"
    homepage "https://go.dev/"

    keg_only :versioned_formula
  
    if OS.mac? && Hardware::CPU.intel?
      url "https://go.dev/dl/go1.22.0.darwin-amd64.tar.gz"
      sha256 "ebca81df938d2d1047cc992be6c6c759543cf309d401b86af38a6aed3d4090f4"
    elsif OS.mac? && Hardware::CPU.arm?
      url "https://go.dev/dl/go1.22.0.darwin-arm64.tar.gz"
      sha256 "bf8e388b09134164717cd52d3285a4ab3b68691b80515212da0e9f56f518fb1e"
    end
  
    keg_only :versioned_formula
  
    depends_on "go" => :build
  
    def install
      ENV["GOROOT_BOOTSTRAP"] = Formula["go"].opt_libexec
  
      cd "src" do
        ENV["GOROOT_FINAL"] = libexec
        # Set portable defaults for CC/CXX to be used by cgo
        with_env(CC: "cc", CXX: "c++") { system "./make.bash" }
      end
  
      libexec.install Dir["*"]
      bin.install_symlink Dir[libexec/"bin/go*"]
  
      system bin/"go", "install", "std", "cmd"
  
      # Remove useless files.
      # Breaks patchelf because folder contains weird debug/test files
      (libexec/"src/debug/elf/testdata").rmtree
      # Binaries built for an incompatible architecture
      (libexec/"src/runtime/pprof/testdata").rmtree
    end
  
    test do
      (testpath/"hello.go").write <<~EOS
        package main
  
        import "fmt"
  
        func main() {
            fmt.Println("Hello World")
        }
      EOS
  
      # Run go fmt check for no errors then run the program.
      # This is a a bare minimum of go working as it uses fmt, build, and run.
      system bin/"go", "fmt", "hello.go"
      assert_equal "Hello World\n", shell_output("#{bin}/go run hello.go")
  
      with_env(GOOS: "freebsd", GOARCH: "amd64") do
        system bin/"go", "build", "hello.go"
      end
  
      (testpath/"hello_cgo.go").write <<~EOS
        package main
  
        /*
        #include <stdlib.h>
        #include <stdio.h>
        void hello() { printf("%s\\n", "Hello from cgo!"); fflush(stdout); }
        */
        import "C"
  
        func main() {
            C.hello()
        }
      EOS
  
      # Try running a sample using cgo without CC or CXX set to ensure that the
      # toolchain's default choice of compilers work
      with_env(CC: nil, CXX: nil) do
        assert_equal "Hello from cgo!\n", shell_output("#{bin}/go run hello_cgo.go")
      end
    end
  end