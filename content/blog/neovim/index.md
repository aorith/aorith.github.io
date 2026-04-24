+++
title = "neovim"
date = "2026-04-24"
taxonomies.tags = [ "neovim" ]
+++

I started using [neovim](https://neovim.io/) when `v0.5.0` was released, that version was the first to introduce `init.lua` as your starting point. I was happy with vim, but always found vimscript cumbersome to use. I like to customize my editor a bit, nothing really complicated or defying the defaults, but you know, some QoL mapping here, a time-saving function there... and vimscript was setting me back.

Lua is a very simple language and contrary to vimscript, I don't need to be constantly searching how to properly create a function, iterate a table or interact with my system like I did with vimscript.

It has been a long time since neovim `v0.5.0`, we are as of the time I'm writing this on the `v0.12.2` release. This release is the first one that makes me realize that neovim is becoming a really stable editor (at last!).

One such feature is a proper built-in package manager, thanks to the help of multiple contributors but specifically [echasnovski](https://github.com/echasnovski/) since it was based on `mini.deps` which is part of [mini.nvim](https://nvim-mini.org/mini.nvim/).

I have to say that the work of Evgeni has improved the neovim plugin ecosystem and neovim itself. I follow his work closely and you can tell that he puts a lot of effort into code quality, user experience and details in general.

I'm a fan of the KISS principle and never liked bloated configurations with tons of plugins and/or over-engineered workflows. Those tend to break soonish and force you to spend time fixing your editor instead of doing actual work. Not to mention the danger of suffering a supply chain attack which grows with each additional external dependency that you have.

But as I said, I do like to customize my editor with small QoLs. One such example of that is a simple and small terminal wrapper function that I have configured with a default action on some filetypes:

```lua
_G.Config = {}

-- Define a custom function to run commands in a terminal.
Config.run_in_terminal = function(cmd)
  if cmd == nil or cmd == '' then
    vim.ui.input({ prompt = 'Command to run: ' }, function(input)
      if input and input ~= '' then Config.run_in_terminal(input) end
    end)
    return
  end

  vim.cmd('terminal ' .. cmd)
end

vim.api.nvim_create_user_command(
  'Term',
  function(opts) Config.run_in_terminal(opts.args ~= '' and opts.args or nil) end,
  { nargs = '?', desc = 'Run command in a terminal' }
)
```

As you can see, `run_in_terminal` is a thin wrapper around `:terminal`, it doesn't do much:

- Asks the user for a command if it wasn't provided
- Runs that command in a terminal

I could just use the plain `:terminal`, but this gives me the flexibility of configuring a default mapping that will ask for a command when the filetype has not overridden it instead of opening the terminal directly, this allows me to use `%` which expands to the current file and/or change the function in the future if for example I want to open it in a new tab.

Then I have the following default mapping:

```lua
-- Run cmd in terminal (overridden in some filetypes)
vim.keymap.set('n', '<Leader>e', '<Cmd>Term<CR>', { desc = 'Run cmd in a terminal' })
```

And I override it on some filetypes like [hurl](https://hurl.dev/):

```lua
-- after/ftplugin/hurl.lua
vim.keymap.set(
  'n',
  '<Leader>e',
  '<Cmd>silent w | Term hurl --color --include --pretty %<CR>',
  { buffer = 0, desc = 'Run this file with Hurl' }
)
```

Or markdown:

```lua
-- after/ftplugin/markdown.lua
vim.keymap.set(
  'n',
  '<Leader>e',
  "<Cmd>silent w | silent Term sh -c 'pandoc -s --embed-resources --toc --syntax-highlighting kate -f markdown -t html5 -o /tmp/.output.html % -c "
    .. vim.env.XDG_CONFIG_HOME
    .. '/'
    .. Config.nvim_appname
    .. "/extra/pandoc.css && open /tmp/.output.html'"
    .. '<CR>',
  { buffer = 0, desc = 'Convert to HTML and open in a Browser' }
)
```

Here is a demo of both in action where I press `<leader>e` to execute the configured terminal action:

<video controls>
  <source src="neovim.mp4" type="video/mp4" />
  Download the
  <a href="neovim.mp4">mp4</a>
  video.
</video>

Of course, there are plugins that can run and manage tasks, open floating terminals, etc. But this is more than enough for me.
