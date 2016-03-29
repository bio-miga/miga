# MiGA CLI

CLI stands for Command Line Interface. This is a set of little scripts that let
you talk with MiGA through the terminal shell. If MiGA is in your PATH (see
[installation details](../part2/installation.md#miga-in-your-path)), you can
simply run `miga` in your terminal, and the help messages will take it from
there. All the MiGA CLI calls look like:

```bash
miga task [options]
```

Where `task` is one of the supported tasks and `[options]` is a set of dash-flag
options supported by each task. `-h` is always there to provide help.

If you're a MiGA administrator, this is probably the most convenient option for
you (but hey, give the [GUI](GUI.md) a chance).
