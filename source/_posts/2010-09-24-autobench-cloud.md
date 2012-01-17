---
layout: post
comments: true
title: Autobench Cloud
tags:
- amazon ec2
- autobench
- benchmark
- httperf
- python
- ubuntu
---
After seeing Nicholas Piël [benchmark](http://nichol.as/benchmark-of-python-
web-servers) a bunch of Python web servers, I was just itching to try some
different configurations. So, I thought I would try to copy his
[autobench](http://www.xenoclast.org/autobench/) setup to do some testing of
my own.

The problem is, where do you get several computers to run the benchmark? And
having to [recompile](http://gom-jabbar.org/articles/2009/02/04/httperf-and-
file-descriptors)
[httperf](http://www.hpl.hp.com/research/linux/httperf/docs.php) on several
machines would be a lot of work.

Amazon EC2 and Ubuntu to the rescue!

The key was that I wanted to be able to launch several instances at once and
only have to connect to one of them to control them all. I thought I would
have to build a custom AMI because I only wanted to do the custom
configuration once.

Turns out, I was wrong. Ubuntu provides [ready-to-go images](http://uec-
images.ubuntu.com/releases/10.04/release/) that can be instantiated with a
custom script.

So, the first thing to do is pick the AMI you want to use from the link above.
I went with us-east-1, 32bit, and EBS root so that I could use micro
instances. You can choose instance root if you want to use small instances.

Next, make sure you have a security group (I created a new one called
Autobench) that permits both SSH and TCP port 4600. You can do all this from
the AWS Management Console.

Next, launch several instances (4 is a nice number) of the AMI you chose
before, but when it asks you for User Data, paste this in there:

``` bash
#!/bin/bash

apt-get update
apt-get -y install checkinstall

# Enables the server to open LOTS of concurrent connections.
printf %s "\
fs.file-max = 128000
net.core.netdev_max_backlog = 2500
net.core.somaxconn = 250000
net.ipv4.ip_local_port_range = 10152 65535
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_max_syn_backlog = 2500
" >> /etc/sysctl.conf
sysctl -p

# Increase the limit on file descriptors.
printf %s "\
*       -       nofile      65535
" >> /etc/security/limits.conf

# Bypass the static compiled file limit in the debian httperf package.
sed -i s/\(__FD_SETSIZE[ 	]\+\)[0-9]\+/\165535/g /usr/include/bits/typesizes.h

# Download, build, and install httperf.
# Checkinstall creates a deb package to meet autobench dependency.
mkdir -p /usr/src
cd /usr/src
wget [ftp://ftp.hpl.hp.com/pub/httperf/httperf-0.9.0.tar.gz](ftp://ftp.hpl.hp.com/pub/httperf/httperf-0.9.0.tar.gz)
tar xvzf httperf-0.9.0.tar.gz
cd httperf-0.9.0
./configure && make
checkinstall --pkgname="httperf" --pkgversion=0.9.0 --pkgrelease=99 --maintainer="foo@bar.com" --provides="httperf" --strip=yes --stripso=yes --backup=no -y

# Download and install autobench.
cd /usr/src
wget [http://www.xenoclast.org/autobench/downloads/debian/autobench_2.1.2_i386.deb](http://www.xenoclast.org/autobench/downloads/debian/autobench_2.1.2_i386.deb)
dpkg -i autobench_2.1.2_i386.deb

# autobenchd upstart script.
printf %s "\
description     \"autobench\"

start on runlevel [2345]
stop on runlevel [!2345]

respawn

exec /usr/bin/autobenchd
" > /etc/init/autobench.conf
start autobench

# Default autobench_admin settings.
printf %s "\
host1 = testhost1
host2 = testhost2
uri1  = /
uri2  = /
port1 = 80
port2 = 80
low_rate = 500
high_rate = 4700
rate_step = 100
num_conn = 400
num_call = 1
timeout = 5
output_fmt = tsv
httperf_hog = NULL
httperf_send-buffer = 4096
httperf_recv-buffer = 16384
clients = localhost:4600
" > /home/ubuntu/.autobench.conf
chown ubuntu:ubuntu /home/ubuntu/.autobench.conf

# Optional custom hosts entries.
printf %s "\
10.1.2.3 example.com [www.example.com](http://www.example.com)
" >> /etc/hosts
```

Make sure you choose the right security group, then launch. Now, be warned
that it can take a good 5-10 minutes for everything to start up and be ready
to go.

If you take a look at the script you'll see that it automatically sets up all
the customizations that Nicholas had in his post. Feel free to tweak the
script for your own purposes.

Finally, make note of the IP or hostnames of your new instances and ssh to any
one of them (ubuntu@instance.amazonaws.com). Assuming you launched them all at
once, you can use internal IPs. Then use something like the following to run a
benchmark:

``` bash
$ autobench_admin --clients localhost:4600,10.1.2.5:4600,10.1.2.6:4600,10.1.2.7:4600 --file bench.tsv --single_host --host1 [www.example.com](http://www.example.com) --uri1 /
```

Note that the default autobench_admin settings we specified in the script will
be divided by the number of instances you have. In particular the number of
connections. That's why I've been going with 4 instances. When I tried 3,
httperf started throwing errors saying that 133.33333 was an invalid number of
connections. So either tweak the number of connections to be evenly divisible
by your number of instances, or choose a nice round number of instances.

Well, that's it for now. Hopefully this will help some of you do some
benchmarks of your own. I've already been comparing uwsgi to gunicorn+gevent.
:)

Please comment if you have any suggestions or tweaks or anything. And let me
know if you do any cool benchmarks using this.

