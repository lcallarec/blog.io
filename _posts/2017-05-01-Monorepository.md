---
layout: post
title: Merge your Git repositories !
subtitle: a.k.a mono-repository
tags:
  - Git
  - Merge repositories
  - mono-repository
---

# The mono-repository

More and more organizations are experiencing the [mono-repository solution](https://syslog.ravelin.com/multi-to-mono-repository-c81d004df3ce) for a while.
Let me explain __why__ I'am enthusiastic about that _other way_ of thinking the version control and beyond, the way you're designing, building and publishing your services.

# Merge your repositories

Here's a very straightforward solution for merging multiple repositories into one.
The objective of this post is more about the __why__ than the __how__, but I'm sure it can helps :p

__Initial situation : two repositories__

* [lcallarec/vala-libluxafor](https://github.com/lcallarec/vala-libluxafor)
* [lcallarec/luxafor-cli](https://github.com/lcallarec/luxafor-cli)

_(will unfortunetalty be deleted at some time)_

__What I want to achieve : merge them to ends with this structure :__

{% highlight bash%}
luxacode
\_libluxafor
 |_ contents of lcallarec/vala-libluxafor
\_ luxafor-cli
 |_ contents of lcallarec/luxafor-cli
{% endhighlight %}

__Step 1 : Create the _luxacode_ repository__

This is the new repository you want to merge in.

{% highlight bash%}
mkdir luxacode
cd luxacode
git init
{% endhighlight %}

__Step 2 : Import vala-libluxafor into libluxafor subdirectory__

_(you must have a local copy of the vala-libluxafor repository in ../vala-libluxafor)_

{% highlight bash%}
mkdir libluxafor

git remote add vala-libluxafor ../vala-libluxafor/
git fetch vala-libluxafor
git merge vala-libluxafor/master
git remote remove vala-libluxafor

# Move manually hidden files, but don't move .git directory
git mv -k * libluxafor
{% endhighlight %}

__Step 2.5 : Commit your changes :)__

__Step 3 : Import luxafor-cli into luxafor-cli subdirectory__

_(you must have a local copy of the luxafor-cli repository in ../luxafor-cli)_

{% highlight bash%}
mkdir libluxafor
git remote add luxafor-cli ../luxafor-cli/
git fetch luxafor-cli
git merge luxafor-cli/master
git remote remove luxafor-cli
# Move manually hidden files, but don't move .git directory
git mv -k * luxafor-cli
{% endhighlight %}

__Step 3.5 : Commit your changes :)__

That's done !

# Why a monolithic repository ?

## My own _(almost)_ real project

__Luxafor-cli__ is a command line tool that control a __[Luxafor](http://www.luxafor.fr/products/)__ device. It depends of __vala-libluxafor__, a library that expose an high-level API to handle an USB luxafor device.

These two projects lived in different git repositories, _because they serve two different purposes. However, be noticed that Luxafor-cli code depends on vala-libluxafor code._

### What was the main difficulties in working with these two repositories ?

* When I build __luxafor-cli__, I usually add modifications to both repositories. I build a fresh shared object from __vala-libluxafor__ to be compiled against luxafor-cli. _Shared objects are made for that, aren't they ?_

* Fortunately, as I'm a bit __lazy__, I automatized the process above. It adds new code that has to be maintained. _Great, I like to maintain new code._

* ... and because I _try_ do to the things _right_, I run the tests on both repositories - with my own-cooked unversionned-script (it can't really fit in either repositories). It adds more complex step to the workflow. _I'm happy to suffer._

* What about `git pull`, `git add`, `git commit`, `git push` twice ? _... fortunately, I don't use branches :p_

* What about `cd ..` and `cd -` or working with many shells ? _I can do lots of things at the same time. But don't tell to my wife about it._

* I can't really complain if no one contribute to my project, the first build is a pain.

### Back to the bias

> These two projects lived in different git repositories, because they serve two different purposes

That's my own thoughts when I created these two repositories.

First, why two different projects, because they serves different purposes, should live in different repositories ?

Because that's the way we learned to use __SVN__ or __Git__ repositories, and we never __questioned__ this _assumption_.

To be clear about the way I like to work with my tools : __a tool is not supposed to drive the way I'm designing, building and publishing my services (_except when it drives in the way I want to go_)__

In my own _(almost)_ real project, _I'm just isolating two projects, when one of them depends on the other_. Looks like a scary idea.

It's usually easier to focus on what separates two things - here, _repositories_, than what links them.

And obviously, they share a lot :

* Same language : __[Vala](https://wiki.gnome.org/Projects/Vala)__
* Common goal : provide tools to interact with a __[Luxafor](http://www.luxafor.fr/products/)__ device, with different purposes
* Same tools, like __make__
* Shared lots of common libraries (like __[LIBUsb](http://libusb.info/)__)

## One repository to rule them all

Moving to one repository was technically straightforward.

After a while, there was some wins :

* __luxafor-cli build__, which depends on __vala-libluxafor__, is straightforward because the source code is always fresh and available. _Flat is better than nested_.

* I can update all parts of the code, either __vala-libluxafor__ or __libluxafor__ without following a complex workflow. _Simple is better than complex_

* When I push my code on github, Travis can run all the tests, for all projects.

* I'm really happy to not use any dependency managers to manage my own private dependencies (yet another post coming out :p) _Although practicality beats purity_

* I've got one __Makefile__ to build all my projects.

# Coming next

While frontiers disappeared, lots of new opportunities appeared as new questions arose.

New horizons can nudge you in unexpected directions...

We'll see that in a __next post__.
