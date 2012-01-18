---
layout: post
comments: true
title: "Redux: Extending the Django User model with inheritance"
tags:
- django
- python
---
I just packaged up and released a small bit of code last night. Mostly because
I wanted to extract it from my project to reuse later, but also because I
thought it was cool enough to share.

It really is small. Just a few lines of code, as it's basically just a clever
use of the InheritanceQuerySet provided by
[django-model-utils](http://bitbucket.org/carljm/django-model-utils/). I
suppose I could have copied that bit of code into my app, but
django-model-utils is small and has some great stuff that I've started using
in all of my projects. So, allow me to share why I thought this bit of code is
useful.

I have a project that I'm working on that requires several different classes
of authenticated users. Each user class has its own required fields and
foreign keys and such.

It was all complicated enough that a single user profile model wasn't going to
cut it. So I tried using a generic foreign key on the user profile that could
be used to point to the "real" profile. Wow, was that a mess.

Another requirement of my project is that all the users belong to a hierarchy.
When a given user logs in, they need to be able to see only those users (and
other things) that are in their downline.

Having to use get_profile, link to the hierarchy, query descendants, and then
reverse the process for each one to get their user data resulted in some
gnarly code, and lots of database queries. I won't even get into trying to get
all of that to display sanely in the admin.

I finally realized that I was in this pickle because best practices say to not
modify the User table. That's when I came across
[this article](http://scottbarnham.com/blog/2008/08/21/extending-the-django-user-model-with-inheritance/)
by Scott Barnham. It made huge sense to me to subclass the User table. The
only problem was that I needed multiple subclasses and that was going to
really complicate things.

In particular, logging in would require additional database queries to figure
out the right User subclass for the user. But, it worked, and now all my
hierarchical queries are much simpler.

Then one day I came across django-model-utils. When I saw the
InheritanceQuerySet, I immediately remembered that ugly code I had slowing
down the login process. What it does is, using some Django 1.2+ features,
determine all subclasses of a model, use select_related for those models, then
return the right subclass based on which one has a matching object. And it
does all that in a single database query.

So I implemented it and it works wonderfully. The only remaining issue was
that the Django admin was throwing errors when I tried to register my User
subclasses using the default UserAdmin. For some reason, when Django validates
a ModelAdmin, it checks to make sure all fields exist on the base model of the
form being used, not the model being registered (now that I think of it, that
might be a bug that I should report).

Fortunately it was pretty easy to fix. I've included a UserAdmin subclass that
overrides the form with a default ModelForm, but then swaps the UserChangeForm
back in on init.

Anyway, that's the story. The package can be found at
[http://pypi.python.org/pypi/django-user-extension/](http://pypi.python.org/pypi/django-user-extension/)
and the source is at
[http://bitbucket.org/dbinit/django-user-extension/](http://bitbucket.org/dbinit/django-user-extension/).

I honestly think this approach is way cleaner and easier than the whole
"profile" approach. Having to add your profile model name to your settings.py
and set up signal handlers to make sure a profile is created when you add a
new user seems overly complicated when you could subclass User and "it just
works."

I wonder what it would take to get something like this rolled into
contrib.auth as an option (or even as the default)?

