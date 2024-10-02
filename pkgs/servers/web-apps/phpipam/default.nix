{ stdenv, lib, fetchurl }:

stdenv.mkDerivation rec {
  pname = "phpipam";
  version = "1.6.0";

  src = fetchurl {
    url = "https://github.com/${pname}/${pname}/releases/download/v${version}/phpipam-v${version}.tgz";
    sha256 = "TSBJfLXgciYbOjWiwK3u2+CBF8pQq6t4T0JrEdypPhE=";
  };

  unpackPhase = ''
    tar -zxf $src
  '';

  installPhase = ''
    mkdir -p $out/
    cp -r * $out  

    # Set correct permissions
    find $out/ -type f -exec chmod 0644 {} \;
    find $out/ -type d -exec chmod 0755 {} \;
  '';

  meta = with lib; {
    description = "Open-source web IP address management application";
    homepage = "https://phpipam.net/";
    license = licenses.gpl3Only;
    platforms = platforms.unix;
    maintainers = with maintainers; [ axiteyt ];
  };
}
