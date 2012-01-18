---
layout: post
comments: true
title: Good ol' SSH
tags:
- ssh
- putty
- plink
- proxycommand
- ssh-config
- netcat
- mac
- osx
---
I've recently started using a Mac as my primary computer. It's been a fairly
easy transition as most everything I work on is already *nix based and the
majority of the software I use is cross-platform.

One thing I did miss was PuTTY. Mostly because I could easily save sessions
and invoke them with "putty -load whatever". Meanwhile, invoking SSH manually
in Terminal was a pain.

Well, that turned out to be quite an easy fix. How is it that I never knew
about ssh-config? Merely create a "~/.ssh/config" file and put in:

```
Host whatever
    HostName  whatever.wherever.com
    User      myuser
```

Now you can just "ssh whatever" from a Terminal window. What a relief!

Next, I used to make use of "plink" as a local proxy command in PuTTY to
create a tunnel through a firewall for work.

How do you do this with regular SSH? Well, Google returns lots of
[results](http://backdrift.org/transparent-proxy-with-ssh) on how to use the
ProxyCommand ssh-config option along with netcat, but that didn't work for me.
Netcat wasn't installed on the firewall.

As it turns out, and I don't know why this was so hard to find, SSH has netcat
built in. So instead of doing something like this:

```
Host whatever
    HostName      whatever.wherever.com
    User          myuser
    ProxyCommand  ssh user@whatever.wherever.com nc %h %p
```

Just replace the last line with this:

```
    ProxyCommand  ssh -W %h:%p user@whatever.wherever.com
```

It does the same thing, just doesn't require netcat. And it works great!
