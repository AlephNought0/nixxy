{
  inputs,
  pkgs,
  config,
  ...
}: {
  imports = [
    ./kitty
    ./shell
    ./tools
    ./vimuwu
    ./mpd
    ./emacs
    ./newsboat
  ];
}
