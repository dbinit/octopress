---
layout: post
title: Easy Django on Windows with CherryPy
description: A simple solution for small projects.
comments: true
tags:
- cherrypy
- django
- windows
- python
- wsgi
---
A while back I had the pleasure of integrating a Django project with a
SharePoint site on IIS. I'll say this: It works.

Getting [isapi-wsgi](http://code.google.com/p/isapi-wsgi/) working with all
the crazy application pool permissions, as well as other issues, was a royal
pain. I also had to switch to a standalone MySQL instance instead of SQL
Server because [django-mssql](http://code.google.com/p/django-mssql/) was
causing all kinds of problems.

It was also practically impossible to replicate the environment for local
development. I had a trial Windows Server VM set up but would constantly run
into issues in production that I hadn't seen in development (mostly related to
permissions).

So, the next time I had the pleasure of working with a Windows server, I
decided to bypass IIS completely and instead use
[CherryPy](http://cherrypy.org/). I should note that this was for a small
internal business application.

There are several packages out there that do this, including
[one](http://pypi.python.org/pypi/django-cherrydev/) I made a while back for
development. The problem is that they were mostly intended to run on *nix or
in development and none of them handle static media (except mine, but it's
outdated and doesn't work with contrib.staticfiles).

So I decided to steal the best parts of my previous app and just make
something simple that I could run with [ServiceEx](http://serviceex.com/).

The cool thing about CherryPy (the full thing, not just the WSGI server) is
that it actually does a decent job with static files and lets you set Expires
headers. It also handles virtual host names so that you can put your static
files on a different subdomain.

Another perk is that, with the help of
[Translogger](http://svn.pythonpaste.org/Paste/trunk/paste/translogger.py)
from the Paste project, you can use Python logging for requests and configure
the access logs with Django.

Anyway, here is the code:

{% gist 1377708 %}

I suppose I could turn this into an app and put it on PyPi... maybe later. I
would like to elaborate on the logging though.

Django 1.3 adds support for configuring standard Python logging in your
"settings.py". So what I've done is use that to also configure the CherryPy
access logs.

``` python
LOGGING = {
    'version': 1,
    'disable_existing_loggers': True,
    'formatters': {
        'simple': {
            'format': '[%(asctime)s] %(levelname)s %(message)s',
            'datefmt': '%d/%b/%Y:%H:%M:%S',
        },
        'verbose': {
            'format': '%(levelname)s %(asctime)s %(module)s %(process)d %(thread)d %(message)s',
            'datefmt': '%a, %d %b %Y %H:%M:%S', # %z',
        },
    },
    'handlers': {
        'console': {
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'stream': 'ext://sys.stdout'
        },
        'console-simple': {
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'formatter': 'simple'
        },
        'console-verbose': {
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'formatter': 'verbose'
        },
        'access-log': {
            'level': 'DEBUG',
            'class': 'logging.handlers.TimedRotatingFileHandler',
            'filename': 'access.log', # Add an appropriate directory to this.
            'when': 'midnight',
            #'backupCount': '30', #approx 1 month worth
        },
        'error-log': {
            'level': 'WARNING',
            'class': 'logging.handlers.TimedRotatingFileHandler',
            'formatter': 'verbose',
            'filename': 'error.log', # Add an appropriate directory to this.
            'when': 'midnight',
            #'backupCount': '30', #approx 1 month worth
        },
        'mail_admins': {
            'level': 'ERROR',
            'class': 'django.utils.log.AdminEmailHandler',
        },
    },
    'loggers': {
        'cherrypy.access': {
            'level':'INFO',
            'handlers':['access-log'],
        },
        'cherrypy.error': {
            'level':'INFO',
            'handlers':['error-log'],
        },
        'django': {
            'level':'INFO',
            'handlers': ['error-log', 'mail_admins'],
        },
    }
}

if 'DJANGO_DISABLE_LOGGING' in os.environ:
    LOGGING_CONFIG = None
```

Notice the last two lines. I ran into an issue where _celeryd_ and
_celerybeat_ were locking the access and error log files on Windows
(preventing them from rotating properly). Since Celery maintains its own logs,
I needed a way to disable Django logging when being loaded from _celeryd_ or
_celerybeat_.

The extra handlers come in handy during development. I have a
"dev_settings.py" that looks something like this:

``` python
from settings import *


DEBUG = True
TEMPLATE_DEBUG = DEBUG

LOGGING['loggers']['cherrypy.access']['handlers'] = ['console']
LOGGING['loggers']['cherrypy.error']['handlers'] = ['console']
LOGGING['loggers']['django']['handlers'] = ['console-simple']
```

That way all the logs are sent to the console, just like the built-in Django
runserver.

So, what is performance like? Well, I haven't stress tested it, but it sure
feels snappy. And it's perfect for a small internal project.

