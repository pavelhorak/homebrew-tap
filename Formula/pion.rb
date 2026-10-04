class Pion < Formula
  desc "Memory engine for AI inference, wire-compatible with Redis"
  homepage "https://pion.pavelhorak.com/"
  url "https://github.com/pavelhorak/pion/releases/download/v0.9.4/pion-0.9.4-macos-arm64.tar.gz"
  sha256 "eed4016c504f82122ea94ac742243acb29289309e38de1bb106295252d4803ee"
  # Pion is Apache-2.0. The bundled libpion_vector (the tuned vector kernels) is
  # under its own binary licence: LICENSE-pion-vector in the tarball.
  license all_of: ["Apache-2.0", :cannot_represent]

  livecheck do
    url :stable
    strategy :github_latest
  end

  # The release binary is built for macOS 14+ on Apple Silicon. Linux has the
  # release tarballs and the ghcr.io/pavelhorak/pion image.
  depends_on arch: :arm64
  depends_on macos: :sonoma

  def install
    libexec.install Dir["*"]
    # The binary's rpath names the build machine's toolchain, so the loader has
    # to be pointed at the bundled runtime libraries. The tarball's
    # pion-server.sh does that with `dirname "$0"`, which breaks when symlinked.
    (bin/"pion-server").write_env_script libexec/"bin/pion-server", DYLD_LIBRARY_PATH: libexec/"lib"
    (var/"pion").mkpath
    (var/"log").mkpath
  end

  def caveats
    <<~EOS
      As a service, Pion listens on 127.0.0.1:1974 with the prompt cache,
      Metal attention and Apple's text embedding on (--kvcache
      --metal-attention --nle-embed), and keeps its WAL, snapshots and
      crash log in:
        #{var}/pion
      Run by hand, it writes them to the directory you start it from.
    EOS
  end

  service do
    # The flags Pion's README and pion-vllm-mlx assume: KV.PREFIX.* (what
    # PionPromptCache calls) answers only with --kvcache, and the semantic
    # cache needs an embedding backend. Idle RSS is about 113 MB with them.
    run [opt_bin/"pion-server", "--port", "1974", "--kvcache", "--metal-attention", "--nle-embed"]
    keep_alive true
    working_dir var/"pion"
    log_path var/"log/pion.log"
    error_log_path var/"log/pion.log"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/pion-server --version")

    port = free_port
    # Start it the way the service does, so a release whose service flags
    # break fails here, before bump.yml moves the formula to it.
    pid = spawn bin/"pion-server", "--port", port.to_s, "--kvcache", "--metal-attention",
                "--nle-embed", "--no-auto-detect"
    begin
      reply = nil
      30.times do
        TCPSocket.open("127.0.0.1", port) do |sock|
          sock.write "*1\r\n$4\r\nPING\r\n"
          reply = sock.gets
        end
        break
      rescue Errno::ECONNREFUSED
        sleep 1
      end
      assert_equal "+PONG\r\n", reply
      # The prompt cache is on: a lookup answers MISS, not "V-store not enabled".
      TCPSocket.open("127.0.0.1", port) do |sock|
        sock.write "*2\r\n$16\r\nKV.PREFIX.LOOKUP\r\n$9\r\nbrew-test\r\n"
        assert_equal "+MISS\r\n", sock.gets
      end
    ensure
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
  end
end
