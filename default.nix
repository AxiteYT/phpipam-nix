{ stdenv, lib, fetchurl, php, makeWrapper, phpPackages }:

stdenv.mkDerivation rec {
  pname = "phpipam";
  version = "1.6.0";

  src = fetchurl {
    url = "https://github.com/${pname}/${pname}ws/releases/download/v${version}/phpipam-v${version}.tgz";
    hash = "";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/www

    # Unpack the source
    tar -xzf $src -C $out/www --strip-components=1    

    # Set correct permissions
    find $out/www -type f -exec chmod 0644 {} \;
    find $out/www -type d -exec chmod 0755 {} \;

    # Copy the sample config to config.php
    cp $out/www/config.dist.php $out/www/config.php

    # Wrap the PHP scripts to include the PHP binary in PATH
    for script in $(find $out/www -name '*.php'); do
      wrapProgram $script --prefix PATH : ${php}/bin
    done
  '';

  propagatedBuildInputs = with phpPackages; [
    php
  ];

  meta = with lib; {
    description = "Open-source web IP address management application";
    homepage = "https://phpipam.net/";
    license = licenses.gpl3Only;
    platforms = platforms.unix;
    maintainers = with maintainers; [ axiteyt ];
  };
}
