{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.programs.zed-editor.enable {
    programs.zed-editor = {
      extensions = [
        "one-dark-pro"
        "nix"
        "scala"
        "neocmake"
        "make"
      ];

      userSettings = {
        lsp = {
          # --- C / C++ ---
          clangd = {
            binary = {
              path = "${pkgs.clang-tools}/bin/clangd";
              arguments = [
                "--background-index"
                "--clang-tidy"
              ];
            };
          };

          # --- Rust ---
          rust-analyzer = {
            binary = {
              path = "${pkgs.rust-analyzer}/bin/rust-analyzer";
            };
            initialization_options = {
              checkOnSave = {
                command = "clippy";
              };
            };
          };

          # --- Python ---
          pyright = {
            binary = {
              path = "${pkgs.pyright}/bin/pyright-langserver";
              arguments = [ "--stdio" ];
            };
          };

          # --- Scala / Chisel ---
          metals = {
            binary = {
              path = "${pkgs.metals}/bin/metals";
              arguments = [ ];
            };
            initialization_options = {
              isHttpEnabled = true;
              statusBarProvider = "on";
            };
          };

          # --- Nix ---
          nil = {
            binary = {
              path = "${pkgs.nil}/bin/nil";
            };
          };
        };
        languages = {
          "Nix" = {
            language_servers = [ "nil" ];
            formatter = {
              external = {
                command = "${pkgs.nixfmt}/bin/nixfmt";
              };
            };
          };
          "Python" = {
            language_servers = [ "pyright" ];
          };
          "Scala" = {
            language_servers = [ "metals" ];
            formatter = {
              language_server = {
                name = "metals";
              };
            };
          };
          "C++" = {
            language_servers = [ "clangd" ];
            formatter = {
              language_server = {
                name = "clangd";
              };
            };
          };
          "C" = {
            language_servers = [ "clangd" ];
            formatter = {
              language_server = {
                name = "clangd";
              };
            };
          };
        };
        git = {
          inline_blame = {
            show_commit_summary = false;
          };
        };
        terminal = {
          toolbar = {
            breadcrumbs = false;
          };
          shell = {
            program = "fish";
          };
        };
        active_pane_modifiers = {
          border_size = 2.0;
          inactive_opacity = 0.8;
        };
        tab_bar = {
          show = true;
        };
        tabs = {
          file_icons = false;
          git_status = true;
        };
        title_bar = {
          show_menus = false;
          show_branch_icon = true;
        };
        status_bar = {
          active_language_button = true;
        };
        project_panel = {
          button = true;
        };
        search = {
          include_ignored = false;
        };
        inlay_hints = {
          enabled = true;
        };
        indent_guides = {
          coloring = "indent_aware";
          active_line_width = 2;
          line_width = 1;
        };
        tab_size = 2;
        hard_tabs = false;
        toolbar = {
          code_actions = true;
          selections_menu = true;
          quick_actions = true;
          breadcrumbs = true;
        };
        minimap = {
          max_width_columns = 70;
          current_line_highlight = "all";
          thumb_border = "left_open";
          show = "auto";
        };
        relative_line_numbers = "enabled";
        auto_signature_help = true;
        autosave = "on_window_change";
        ui_font_weight = 500.0;
        buffer_font_family = "Maple Mono NF CN";
        vim_mode = true;
        ui_font_size = 20.0;
        buffer_font_size = 15;
        theme = "One Dark Pro";
      };
    };
  };
}
