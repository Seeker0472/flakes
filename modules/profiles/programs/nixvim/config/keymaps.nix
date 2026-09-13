{ lib, ... }:
let
  normalMap = key: action: desc: {
    mode = "n";
    inherit key action;
    options = {
      inherit desc;
      silent = true;
    };
  };

  visualMap = key: action: desc: {
    mode = "x";
    inherit key action;
    options = {
      inherit desc;
      silent = true;
    };
  };

  # Keep the same mappings useful outside Zellij while allowing zellij-nav to
  # cross the boundary when the current Neovim window is already at an edge.
  zellijNavMap = key: functionName: fallbackDirection: desc: {
    mode = "n";
    inherit key;
    action = lib.nixvim.mkRaw ''
      function()
        if vim.env.ZELLIJ ~= nil then
          require("zellij-nav").${functionName}()
        else
          vim.cmd("wincmd ${fallbackDirection}")
        end
      end
    '';
    options = {
      inherit desc;
      silent = true;
    };
  };
in
{
  keymaps = [
    (normalMap "<Esc>" "<cmd>nohlsearch<cr>" "Clear search highlight")
    (normalMap "<leader>w" "<cmd>write<cr>" "Write buffer")
    (normalMap "<leader>q" "<cmd>confirm quit<cr>" "Quit window")
    (normalMap "<leader>Q" "<cmd>confirm qall<cr>" "Quit Neovim")

    (zellijNavMap "<C-h>" "left_tab" "h" "Focus left window or pane")
    (zellijNavMap "<C-j>" "down" "j" "Focus lower window or pane")
    (zellijNavMap "<C-k>" "up" "k" "Focus upper window or pane")
    (zellijNavMap "<C-l>" "right_tab" "l" "Focus right window or pane")
    (normalMap "<leader>-" "<cmd>split<cr>" "Split below")
    (normalMap "<leader>|" "<cmd>vsplit<cr>" "Split right")

    (normalMap "[b" "<cmd>bprevious<cr>" "Previous buffer")
    (normalMap "]b" "<cmd>bnext<cr>" "Next buffer")
    (normalMap "<leader>bd" (lib.nixvim.mkRaw ''
      function()
        require("mini.bufremove").delete(0, false)
      end
    '') "Delete buffer")

    (visualMap "J" "<cmd>move '>+1<cr>gv=gv" "Move selection down")
    (visualMap "K" "<cmd>move '<-2<cr>gv=gv" "Move selection up")
    (visualMap "<" "<gv" "Indent selection left")
    (visualMap ">" ">gv" "Indent selection right")

    {
      mode = "t";
      key = "<Esc><Esc>";
      action = "<C-\\><C-n>";
      options = {
        desc = "Enter terminal normal mode";
        silent = true;
      };
    }
  ];
}
