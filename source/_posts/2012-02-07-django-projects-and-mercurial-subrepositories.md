---
layout: post
title: Django Projects and Mercurial Subrepositories
description: Using hg subrepos for fun and profit.
comments: true
tags:
- python
- django
- vcs
- git
- mercurial
- subversion
- pip
- virtualenv
---
A while back, Steve Losh posted some excellent [Django advice](http://stevelosh.com/blog/2011/06/django-advice/),
in particular the part on [working with third-party apps](http://stevelosh.com/blog/2011/06/django-advice/#installing-apps-from-repositories).
I thought it sounded interesting but was concerned that it would be a hassle
to maintain.

Once I finally tried it, it was quite liberating. Never again will I have to
work around some issue with a package. Now I just fix it and move on.

It did take a bit of work, though, to figure out an approach that I was happy
with. I usually use a [pip requirements file](http://www.pip-installer.org/en/latest/requirements.html)
to keep track of project dependencies and I wasn't quite sure how to make it
all work together.

One option is to use pip's ``editable`` flag like so:

``` bash requirements.txt
-e hg+https://bitbucket.org/andrewgodwin/south@64fdcc52cd010e663b7a8b9ad592d4aa204807a2#egg=South-dev
```

What I didn't like about that was having to constantly update my
requirements.txt to change the revision. And, by default, pip installs
editable packages into ``$VIRTUAL_ENV/src`` while I'd rather they be in a
subdirectory of my project for easy access.

My first attempt at dealing with those issues was to fork every single
package I was using, add a tag or branch for the revision my project was using
and change the requirements.txt file to look like so:

``` bash requirements.txt
-e hg+https://bitbucket.org/dbinit/south@myproject#egg=South-dev
```

Then I would manually specify the source directory when installing, like so:

``` bash
$ pip install --src=./src -r requirements.txt
```

The problems with this approach were that I was now maintaining forks of all
these apps, it was just as tedious to be moving tags around as updating the
revision hash, and now the requirements file wasn't self-contained.

What I really wanted was to add all the apps as [subrepositories](http://mercurial.selenic.com/wiki/Subrepository)
to my project's Mercurial repository. That way the revisions would be tracked
automatically and no need for tags.

The hard part was getting pip to install these packages as editable without
making a copy somewhere. It took some trial and error to get right... though
I did finally figure it out (hint: don't use ```file:``` or ```#egg```):

``` bash requirements.txt
-e lib/south
```

So now, when I want to add an app to my project, I first clone it to the
project's ``lib`` subdirectory. Then I add the above entry to my requirements
file and the following entry in ``.hgsub``:

``` ini \.hgsub
lib/south = https://bitbucket.org/andrewgodwin/south
```

Finally, I install the package into my virtualenv with:

``` bash
$ pip install -r requirements.txt
```

You might also want to add the following to your project's ``.hg/hgrc`` file
to avoid automatically committing the subrepos:

``` ini hgrc
[ui]
commitsubrepos = False
```

Don't forget that you can also include apps that are in [git or svn](http://mercurial.selenic.com/wiki/Subrepository#Non-Mercurial_Subrepositories).
