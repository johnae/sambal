with import <nixpkgs> {};

stdenv.mkDerivation {
 name = "sambal";
 buildInputs = [ ruby rake samba ];
}
