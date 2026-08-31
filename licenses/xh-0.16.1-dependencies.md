# xh 0.16.1 embedded dependency inventory

This inventory was derived from Cargo registry source paths embedded in ForecastInk's bundled `bin/xh` executable and checked against the crates.io metadata for each exact version. It is an audit aid; each component remains subject to its own license text and copyright notices.

The binary also contains Rust standard-library code built with Rust 1.62.1 (`e092d0b6b43f2de967af0887873151bb1c0b18d3`), licensed under MIT or Apache-2.0, and appears to use the musl C runtime, licensed under MIT-style terms. The TLS stack includes `ring` 0.16.20 and WebPKI 0.22.0; their exact custom/ISC license files are included beside this inventory.

| Crate | Version | License expression from crates.io | Upstream repository |
|---|---:|---|---|
| `addr2line` | 0.16.0 | `Apache-2.0/MIT` | https://github.com/gimli-rs/addr2line |
| `aho-corasick` | 0.7.18 | `Unlicense/MIT` | https://github.com/BurntSushi/aho-corasick |
| `anyhow` | 1.0.44 | `MIT OR Apache-2.0` | https://github.com/dtolnay/anyhow |
| `base64` | 0.13.0 | `MIT/Apache-2.0` | https://github.com/marshallpierce/rust-base64 |
| `block-buffer` | 0.9.0 | `MIT OR Apache-2.0` | https://github.com/RustCrypto/utils |
| `brotli-decompressor` | 2.3.2 | `BSD-3-Clause/MIT` | https://github.com/dropbox/rust-brotli-decompressor |
| `bytes` | 1.1.0 | `MIT` | https://github.com/tokio-rs/bytes |
| `chardetng` | 0.1.15 | `Apache-2.0 OR MIT` | https://github.com/hsivonen/chardetng |
| `clap` | 3.1.0 | `MIT OR Apache-2.0` | https://github.com/clap-rs/clap |
| `clap_complete` | 3.1.0 | `MIT OR Apache-2.0` | https://github.com/clap-rs/clap/tree/master/clap_complete |
| `console` | 0.14.1 | `MIT` | https://github.com/mitsuhiko/console |
| `cookie` | 0.15.1 | `MIT OR Apache-2.0` | https://github.com/SergioBenitez/cookie-rs |
| `cookie_store` | 0.15.0 | `MIT/Apache-2.0` | https://github.com/pfernie/cookie_store |
| `digest_auth` | 0.3.0 | `MIT` | https://git.ondrovo.com/packages/digest_auth_rs |
| `encoding_rs` | 0.8.29 | `Apache-2.0 OR MIT` | https://github.com/hsivonen/encoding_rs |
| `encoding_rs_io` | 0.1.7 | `MIT OR Apache-2.0` | https://github.com/BurntSushi/encoding_rs_io |
| `flate2` | 1.0.22 | `MIT/Apache-2.0` | https://github.com/rust-lang/flate2-rs |
| `form_urlencoded` | 1.0.1 | `MIT/Apache-2.0` | https://github.com/servo/rust-url |
| `futures-channel` | 0.3.17 | `MIT OR Apache-2.0` | https://github.com/rust-lang/futures-rs |
| `futures-core` | 0.3.17 | `MIT OR Apache-2.0` | https://github.com/rust-lang/futures-rs |
| `futures-util` | 0.3.17 | `MIT OR Apache-2.0` | https://github.com/rust-lang/futures-rs |
| `getrandom` | 0.2.3 | `MIT OR Apache-2.0` | https://github.com/rust-random/getrandom |
| `gimli` | 0.25.0 | `Apache-2.0/MIT` | https://github.com/gimli-rs/gimli |
| `h2` | 0.3.13 | `MIT` | https://github.com/hyperium/h2 |
| `hashbrown` | 0.11.2 | `Apache-2.0/MIT` | https://github.com/rust-lang/hashbrown |
| `hashbrown` | 0.12.0 | `Apache-2.0/MIT` | https://github.com/rust-lang/hashbrown |
| `http` | 0.2.4 | `MIT/Apache-2.0` | https://github.com/hyperium/http |
| `httparse` | 1.5.1 | `MIT/Apache-2.0` | https://github.com/seanmonstar/httparse |
| `hyper` | 0.14.12 | `MIT` | https://github.com/hyperium/hyper |
| `hyper-rustls` | 0.23.0 | `Apache-2.0/ISC/MIT` | https://github.com/ctz/hyper-rustls |
| `idna` | 0.2.3 | `MIT/Apache-2.0` | https://github.com/servo/rust-url/ |
| `indexmap` | 1.7.0 | `Apache-2.0/MIT` | https://github.com/bluss/indexmap |
| `indicatif` | 0.16.2 | `MIT` | https://github.com/mitsuhiko/indicatif |
| `ipnet` | 2.3.1 | `MIT OR Apache-2.0` | https://github.com/krisprice/ipnet |
| `jsonxf` | 1.1.1 | `MIT` | https://github.com/gamache/jsonxf |
| `lazy_static` | 1.4.0 | `MIT/Apache-2.0` | https://github.com/rust-lang-nursery/lazy-static.rs |
| `lazycell` | 1.3.0 | `MIT/Apache-2.0` | https://github.com/indiv0/lazycell |
| `memchr` | 2.4.1 | `Unlicense/MIT` | https://github.com/BurntSushi/memchr |
| `mime` | 0.3.16 | `MIT/Apache-2.0` | https://github.com/hyperium/mime |
| `mime2ext` | 0.1.49 | `MIT` | https://github.com/blyxxyz/mime2ext |
| `miniz_oxide` | 0.4.0 | `MIT` | https://github.com/Frommi/miniz_oxide/tree/master/miniz_oxide |
| `miniz_oxide` | 0.4.4 | `MIT OR Zlib OR Apache-2.0` | https://github.com/Frommi/miniz_oxide/tree/master/miniz_oxide |
| `mio` | 0.7.13 | `MIT` | https://github.com/tokio-rs/mio |
| `num_cpus` | 1.13.0 | `MIT/Apache-2.0` | https://github.com/seanmonstar/num_cpus |
| `once_cell` | 1.8.0 | `MIT OR Apache-2.0` | https://github.com/matklad/once_cell |
| `onig` | 6.2.0 | `MIT` | http://github.com/iwillspeak/rust-onig |
| `os_display` | 0.1.3 | `MIT` | https://github.com/blyxxyz/os_display |
| `os_str_bytes` | 6.0.0 | `MIT OR Apache-2.0` | https://github.com/dylni/os_str_bytes |
| `pem` | 0.8.3 | `MIT` | https://github.com/jcreekmore/pem-rs.git |
| `percent-encoding` | 2.1.0 | `MIT/Apache-2.0` | https://github.com/servo/rust-url/ |
| `rand` | 0.8.4 | `MIT OR Apache-2.0` | https://github.com/rust-random/rand |
| `rand_chacha` | 0.3.1 | `MIT OR Apache-2.0` | https://github.com/rust-random/rand |
| `regex` | 1.5.4 | `MIT OR Apache-2.0` | https://github.com/rust-lang/regex |
| `regex-syntax` | 0.6.25 | `MIT/Apache-2.0` | https://github.com/rust-lang/regex |
| `reqwest` | 0.11.10 | `MIT/Apache-2.0` | https://github.com/seanmonstar/reqwest |
| `ring` | 0.16.20 | `non-standard` | https://github.com/briansmith/ring |
| `rustc-demangle` | 0.1.21 | `MIT/Apache-2.0` | https://github.com/alexcrichton/rustc-demangle |
| `rustls` | 0.20.4 | `Apache-2.0/ISC/MIT` | https://github.com/rustls/rustls |
| `rustls-pemfile` | 0.3.0 | `Apache-2.0/ISC/MIT` | https://github.com/rustls/pemfile |
| `rustls-pemfile` | 1.0.0 | `Apache-2.0/ISC/MIT` | https://github.com/rustls/pemfile |
| `sct` | 0.7.0 | `Apache-2.0/ISC/MIT` | https://github.com/ctz/sct.rs |
| `serde` | 1.0.130 | `MIT OR Apache-2.0` | https://github.com/serde-rs/serde |
| `serde_json` | 1.0.67 | `MIT OR Apache-2.0` | https://github.com/serde-rs/json |
| `slab` | 0.4.4 | `MIT` | https://github.com/tokio-rs/slab |
| `socket2` | 0.4.1 | `MIT/Apache-2.0` | https://github.com/rust-lang/socket2 |
| `spin` | 0.5.2 | `MIT` | https://github.com/mvdnes/spin-rs.git |
| `strsim` | 0.10.0 | `MIT` | https://github.com/dguo/strsim-rs |
| `syntect` | 4.6.0 | `MIT` | https://github.com/trishume/syntect |
| `termcolor` | 1.1.2 | `Unlicense OR MIT` | https://github.com/BurntSushi/termcolor |
| `textwrap` | 0.14.2 | `MIT` | https://github.com/mgeisler/textwrap |
| `time` | 0.2.27 | `MIT OR Apache-2.0` | https://github.com/time-rs/time |
| `tinyvec` | 1.4.0 | `Zlib OR Apache-2.0 OR MIT` | https://github.com/Lokathor/tinyvec |
| `tokio` | 1.11.0 | `MIT` | https://github.com/tokio-rs/tokio |
| `tokio-rustls` | 0.23.3 | `MIT/Apache-2.0` | https://github.com/tokio-rs/tls |
| `tokio-socks` | 0.5.1 | `MIT` | https://github.com/sticnarf/tokio-socks |
| `tokio-util` | 0.7.1 | `MIT` | https://github.com/tokio-rs/tokio |
| `tracing` | 0.1.26 | `MIT` | https://github.com/tokio-rs/tracing |
| `tracing-core` | 0.1.19 | `MIT` | https://github.com/tokio-rs/tracing |
| `unicode-normalization` | 0.1.19 | `MIT/Apache-2.0` | https://github.com/unicode-rs/unicode-normalization |
| `untrusted` | 0.7.1 | `ISC` | https://github.com/briansmith/untrusted |
| `url` | 2.2.2 | `MIT/Apache-2.0` | https://github.com/servo/rust-url |
| `want` | 0.3.0 | `MIT` | https://github.com/seanmonstar/want |
| `webpki` | 0.22.0 | `non-standard` | https://github.com/briansmith/webpki |

License expressions containing `/` are legacy crates.io syntax for a choice of licenses. `OR` likewise means the recipient may choose one of the stated licenses. `ring` uses a non-SPDX custom combination that includes ISC-style, OpenSSL, and SSLeay-derived terms; see [`ring-0.16.20-LICENSE.txt`](ring-0.16.20-LICENSE.txt) and [`ring-0.16.20-fiat-LICENSE.txt`](ring-0.16.20-fiat-LICENSE.txt). WebPKI's main license is ISC-style; see [`webpki-0.22.0-LICENSE.txt`](webpki-0.22.0-LICENSE.txt) and its Chromium-derived notice in [`webpki-0.22.0-chromium-LICENSE.txt`](webpki-0.22.0-chromium-LICENSE.txt).
