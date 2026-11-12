{ runCommandLocal }:
runCommandLocal "new-software-skill" { } ''
  mkdir -p $out/share/skills/new-software
  cp -r ${./skill} $out/share/skills/new-software/new-software
''
