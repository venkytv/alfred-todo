alfred-todo
===========

An Alfred v2 Workflow for [todo.txt](http://todotxt.com/).

Expects the "todo.sh" script in "/usr/local/bin".  If you have it installed in a
different directory, or if you want to configure a couple of other parameters,
type "t conf" into Alfred and pick the "Configure the workflow" option.

You can download the workflow [here](https://github.com/venkytv/alfred-todo/raw/master/Alfred-TODO.alfredworkflow).

usage
-----

Basic usage -- type the keyword (default: 't') followed by the text of the todo
item you want to add or mark as done.  With an existing task, hold down the
"Control" key to delete the task instead of marking it as done.

![Add Task](/screenshots/add-task.png?raw=true)
![Mark as Done](/screenshots/mark-as-done.png?raw=true)

You can change the priority of a todo item by typing "t p " followed by the text
of the todo or its ID and ending with a single alphabet which will be the new
priority.

![Reprioritise](/screenshots/reprioritise-alt.png?raw=true)

A shortcut for setting the priority while adding a new task -- add the priority
preceded by a "!" to the end of the todo.

![Add Prioritised Task](/screenshots/add-prioritised-task.png?raw=true)
![Reprioritise](/screenshots/reprioritise.png?raw=true)
