{...}: {
  boot = {
    initrd = {
      supportedFilesystems = ["btrfs"];
    };
  };
}