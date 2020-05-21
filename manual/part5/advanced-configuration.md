# Advanced configuration

MiGA allows flexible execution using a number of techniques, mainly
setting [project metadata flags](metadata.md#project-flags),
[dataset metadata flags](metadata.md#dataset-flags), and through the
[daemon configuration](../part4/daemons.md).

These are some examples of advanced behaviors that can be configured
in MiGA

## Controlling many daemons at once

The [MiGA CLI](../part3/miga-cli.md) includes support for mass-controlled
daemons when several MiGA projects are in the same folder using the
`miga lair` command.

The MiGA Lair will find all the MiGA projects in a folder (or subfolders)
and control all the corresponding daemons together:

```bash
# Check the current status of all the daemons
miga lair list -p /path/to/folder

# Terminate all the daemons at once
miga lair terminate -p /path/to/folder

# Launch and daemonize a process to keep all daemons running
miga lair start -p /path/to/folder

# See more options
miga lair -h
```

## Sending an email when the project is ready

If your project runs for a long time and you want to be notified by email
when it's ready, you can use [project hooks](metadata.md#project-hooks):

```bash
# First cd to the project folder
cd /path/to/project

# And open the MiGA Console
miga c
```

In the MiGA Console:

```ruby
# Set the hook "on_preprocessing_ready" to
# execute a shell command ("run_cmd") consisting of
# sending an email with the project path ("{{project}}")
MiGA::Project.load('.').tap do |p|
  p.metadata[:on_preprocessing_ready] = [
    ['run_cmd', 'echo \'Project ready: {{project}}\' | sendmail me@example.com']
  ]
end.save
quit
```

Make sure to change `/path/to/project` to the project path and
`me@example.com` to the email where you want to receive the notification.
Also, note that depending on your `sendmail` configuration you might get
that email in the spam folder (or flat-out rejected),
so make sure to test `sendmail` first.


