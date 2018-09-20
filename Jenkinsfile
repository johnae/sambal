#!/usr/bin/groovy

def hasCmd(cmd) { "command -v ${cmd} >/dev/null 2>&1" }

def shell(cmd) {
  def nixInitPath = '$HOME/.nix-profile/etc/profile.d/nix.sh'
  sh """
     if ! ${hasCmd('nix-shell')}; then
        if [ -e ${nixInitPath} ]; then
           . ${nixInitPath}
        else
           curl https://nixos.org/nix/install | sh
           . ${nixInitPath}
        fi
     fi
     ${cmd}
     """
}

def nixShell(cmd) { shell """ nix-shell --run "${cmd}" """ }

node('linux') {
  stage("Prerequisites") { shell """ nix-env -iA nixpkgs.git """ }

  stage("Checkout") { checkout scm }

  stage("Setup") { nixShell '''
                            bundle install
                            mkdir -p /tmp/sambal-temp-path
                            '''
                 }

  stage("Test") { nixShell "SAMBAL_TEMP_PATH=/tmp/sambal-temp-path bundle exec rspec" }
}