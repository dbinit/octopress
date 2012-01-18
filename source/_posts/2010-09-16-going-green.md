---
layout: post
comments: true
title: Going Green
tags:
- django
- gevent
- gunicorn
- postgresql
- psycopg
- python
- wsgi
---
There are so many ways to serve up Django and other WSGI apps. I've used nginx
and uWSGI (thanks to a great [blog post](http://blog.zacharyvoase.com/2010/03/05/django-uwsgi-nginx/)
by Zachary Voase), IIS and isapi-wsgi, Apache and mod_wsgi, and even CherryPy as a
development "runserver" replacement.

I've recently started hearing more and more about asynchronous servers,
lightweight threads, and greenlets and such. I also came across the [Green Unicorn](http://gunicorn.org/)
project that, though [not very speedy](http://nichol.as/benchmark-of-python-web-servers)
with its default worker class, has recently integrated gevent to make it a very
attractive offering.

This post describes how I got a Django project up and running on
[WebFaction](http://www.webfaction.com/?affiliate=ungenio) (affiliate link)
using Gunicorn and gevent. It was quite fun!

One of the advantages of using this method on WebFaction in particular is that
they already have nginx running in front of all your apps. It bothered me,
when using uWSGI, that I had to have an additional nginx instance running, or
having to run full blown Apache to use mod_wsgi. Simpler is better and, even
though I opted to compile some things, Gunicorn _seemed_ simpler. Especially
when it came to finally running the Django project.

Install [Python](http://www.python.org/)
----------------------------------------

As you'll see with most of this, I like to play with the latest and greatest.
So, the first thing I chose to do, and it's completely optional, is install
the latest version of Python (2.7 as of this post). This was quite simple and
only takes a few steps:

``` bash
$ mkdir ~/src
$ cd ~/src
$ wget http://python.org/ftp/python/2.7/Python-2.7.tar.bz2
$ tar xjvf Python-2.7.tar.bz2
$ cd Python-2.7
$ ./configure --prefix=$HOME
$ make
$ make install
```

That's it. Now just make sure you have something like the following in your
~/.bashrc file:

``` bash
export PATH=$HOME/bin:$PATH
export LD_LIBRARY_PATH=$HOME/lib
```

The library path is needed later for Gunicorn to be able to find libevent.
Also, make sure you activate your changes after editing the file:

``` bash
$ source ~/.bashrc
```

Install Packages
----------------

Next, you'll probably want distribute, pip, and virtualenv:

``` bash
$ cd ~/src
$ curl http://python-distribute.org/distribute_setup.py | python
$ easy_install pip
$ pip install virtualenv
```

I also like to install certain support packages that I tend to use in every
virtual environment. If you have other things running, you might want to put
all of these in the virtualenv we'll make further down:

``` bash
$ pip install mercurial ipython psycopg2 python-memcached setproctitle greenlet
```

* Mercurial: pretty self explanatory.
* IPython: I just recently discovered this very nice Python shell replacement. Django's "python manage.py shell" will use it if installed.
* Psycopg2: I prefer PostgreSQL to MySQL (partly because I'm using PostGIS for some stuff) and this adapter recently [added support](http://initd.org/psycopg/docs/advanced.html#support-to-coroutine-libraries) for gevent (details below).
* Python-memcached: I'll go over this in a separate post.
* setproctitle: This little utility lets Gunicorn change its process name as seen in ps and top. Quite handy.
* greenlet: Used by gevent, which we'll be installing below.

Install [libevent](http://monkey.org/~provos/libevent/)
-------------------------------------------------------

This might be optional on WebFaction. It appears to already be installed
(along with memcached), but I like to run the latest and greatest (1.4.14b as
of this post):

``` bash
$ cd ~/src
$ wget http://monkey.org/~provos/libevent-1.4.14b-stable.tar.gz
$ tar xzvf libevent-1.4.14b-stable.tar.gz
$ cd libevent-1.4.14b-stable
$ ./configure --prefix=$HOME
$ make
$ make install
```

Install [gevent](http://www.gevent.org/)
----------------------------------------

This can be installed with pip, but we have to tell it where we installed
libevent:

``` bash
$ pip install --install-option="-I$HOME/include" --install-option="-L$HOME/lib" gevent
```

And that's it for preliminaries. I wait to install Gunicorn into the
virtualenv because it provides its own scripts that will automatically
activate/use the right python executable (which makes things very simple).

Create an app
-------------

On WebFaction, you'll now need to go to your control panel and add a new
"Custom app (listening on port)". Make sure you make note of the port it
assigns. You will also want to assign the app to a site (see WebFaction docs
on how to do that).

With the app created, let's make it a virtualenv and install Django and
Gunicorn:

``` bash
$ cd ~/webapps
$ virtualenv --distribute myapp
$ cd myapp
$ source bin/activate
$ easy_install -U pip
$ pip install -U distribute
$ pip install django docutils gunicorn
```

You might notice that the first thing I did was upgrade pip and distribute. It
just annoys me that virtualenv installs old versions. :)

Create a Django project
-----------------------

Now we'll create an empty Django project and set it up for use with Gunicorn:

```
$ cd ~/webapps/myapp
$ source bin/activate
$ django-admin.py startproject myproject
$ cd myproject
$ wget http://bitbucket.org/dvarrazzo/psycogreen/raw/tip/gevent/psyco_gevent.py
```

The psyco_gevent.py module will help us activate gevent support in psycopg2.
We're dropping it in the main project directory so that we can import it, but
you could also put it anywhere else you can import from (like site-packages).
You might also want to clone the repository somewhere (hg clone
[http://bitbucket.org/dvarrazzo/psycogreen](http://bitbucket.org/dvarrazzo/psycogreen))
and then copy the file from there.

Next, load up your favorite editor to edit your settings.py. I like to make
sure the project path and virtualenv path are both in the Python system path.
It's also nice to be able to access SITE_ROOT from settings later. For now
we'll just configure the database and enable the admin:

``` python
# At the top
import sys
from os import path

PROJECT_ROOT = path.dirname(path.abspath(__file__))
sys.path.append(PROJECT_ROOT)
SITE_ROOT = path.dirname(PROJECT_ROOT)
sys.path.append(SITE_ROOT)

# ...

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': 'mydatabase',
        'USER': 'myuser',
        'PASSWORD': 'mypassword',
        'HOST': '',
        'PORT': '',
    }
}

# ...

INSTALLED_APPS = (
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.sites',
    'django.contrib.messages',
    'django.contrib.admin',
    'django.contrib.admindocs',
)
```

Of course there's a lot more you would probably want to do in there for a real
project. The database settings assume you have a PostgreSQL database already
created. If you don't, you can add one through the WebFaction control panel.

Make sure you edit your urls.py as well. For starting out with just the admin
it can look like the following:

``` python
from django.conf.urls.defaults import *
from django.contrib import admin


admin.autodiscover()


urlpatterns = patterns('',
    (r'^admin/doc/', include('django.contrib.admindocs.urls')),
    (r'^admin/', include(admin.site.urls)),
)
```

And finally, we'll run syncdb to create tables and an admin user:

``` bash
$ cd ~/webapps/myapp
$ source bin/activate
$ cd myproject
$ python manage.py syncdb
```

Configure Gunicorn
------------------

Finally, let's create a Gunicorn configuration file. I like to put it in an
etc directory:

``` bash
$ mkdir ~/webapps/myapp/etc
```

I called mine gunicorn.conf, but you're free to name it whatever. The nice
thing is you can put whatever Python code you want in there. So make it look
something like this (replace <myport> with the port assigned to you by the
WebFaction control panel):

``` python
bind = "127.0.0.1:"
workers = 3
worker_class = "gevent"

def def_post_fork(server, worker):
    from psyco_gevent import make_psycopg_green
    make_psycopg_green()
    worker.log.info("Made Psycopg Green")

post_fork = def_post_fork
```

What this does is load 3 gevent workers (feel free to tweak that... I keep it
low because of memory limits on WebFaction) and run the make_psycopg_green
function every time it forks a new worker.

Run Gunicorn
------------

All that's left now is to run Gunicorn. We're just going to run it from the
command line for now. I have it set up to run in Supervisord, but I'll leave
that for the next post. Notice that you don't even have to activate the
virtualenv:

``` bash
$ cd ~/webapps/myapp/myproject
$ ../bin/gunicorn_django -c ../etc/gunicorn.conf
```

Your site should be up and running. Just go to
http://mysite.com/admin to verify the admin is
running.

That's it! I hope this helps someone. Let me know what you think.

