{
  "description": "{{FLAKE_NAME}} — {{FLAKE_DESC}}",
  "inputs": {
    "nixpkgs": {
      "url": "github:NixOS/nixpkgs/nixos-unstable"
    }
  },
  "outputs": "outputs = { self, nixpkgs, ... }: { }"
}
