{
  description = "Stereoscopic hardware project for depth mapping";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };
  
  outputs = {
    nixpkgs,
    treefmt-nix,
    ...
  }: let
    supportedSystems = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
  in {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs {
        inherit system;
      };
    in {
      default = pkgs.buildGo124Module {
        pname = "opencode";
        version = "0.1.0";
        src = ./.;
        vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        doCheck = false;
        
        preBuild = ''
          go generate ./...
        '';
        
        meta = with pkgs.lib; {
          description = "Stereoscopic hardware project for depth mapping";
          homepage = "https://github.com/conneroisu/opencode";
          license = licenses.mit;
          maintainers = with maintainers; [];
        };
      };
    });

    devShells = forAllSystems (system: let
      pkgs = import nixpkgs {
        inherit system;
      };

      scripts = {
        dx = {
          exec = ''$EDITOR "$REPO_ROOT"/flake.nix'';
          description = "Edit flake.nix";
        };
        gx = {
          exec = ''$EDITOR "$REPO_ROOT"/go.mod'';
          description = "Edit go.mod";
        };
        build-go = {
          exec = ''go build ./...'';
          description = "Build all go packages";
        };
        clean = {
          exec = ''go clean -cache -testcache -modcache'';
          description = "Clean Project";
        };
        format = {
          exec = ''
            echo "Running gofmt..."
            gofmt -w .
            echo "Running golines..."
            find . -name "*.go" -type f | xargs -I {} golines -w {}
          '';
          description = "Format code files";
        };
        generate-js = {
          exec = ''go generate ./...'';
          description = "Generate JS files";
        };
        lint = {
          exec = ''golangci-lint run'';
          description = "Run Linting Steps for go files";
        };
        live-reload = {
          exec = ''air'';
          description = "Reload the application for air";
        };
        run = {
          exec = ''air'';
          description = "Run the application with air for hot reloading";
        };
        tests = {
          exec = ''go test ./...'';
          description = "Run all go tests";
        };
      };

      scriptPackages =
        pkgs.lib.mapAttrs
        (
          name: script:
            pkgs.writeShellApplication {
              inherit name;
              text = script.exec;
              runtimeInputs = script.deps or [];
            }
        )
        scripts;

      buildWithSpecificGo = pkg: pkg.override {buildGoModule = pkgs.buildGo124Module;};
    in {
      default = pkgs.mkShell {
        name = "opencode-dev";

        packages = with pkgs;
          [
            # Nix tools
            alejandra
            nixd
            statix
            deadnix

            # Go Tools
            go_1_24
            air
            golangci-lint
            gopls
            (buildWithSpecificGo revive)
            (buildWithSpecificGo golines)
            (buildWithSpecificGo golangci-lint-langserver)
            (buildWithSpecificGo gomarkdoc)
            (buildWithSpecificGo gotests)
            (buildWithSpecificGo gotools)
            (buildWithSpecificGo reftools)
            pprof
            graphviz
            goreleaser
            cobra-cli
            
            # Web development tools (mentioned in CLAUDE.md)
            nodePackages.tailwindcss
            bun
            nodePackages.typescript-language-server
          ]
          ++ builtins.attrValues scriptPackages;

        shellHook = ''
          export REPO_ROOT=$(git rev-parse --show-toplevel)
          echo "OpenCode development environment loaded"
          echo "Run 'run' or 'air' to start the server with hot reloading"
          echo "Run 'tests' to run all tests"
        '';
      };
    });

    formatter = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      treefmtModule = {
        projectRootFile = "flake.nix";
        programs = {
          alejandra.enable = true; # Nix formatter
          gofmt.enable = true; # Go formatter
        };
      };
    in
      treefmt-nix.lib.mkWrapper pkgs treefmtModule);
  };
}