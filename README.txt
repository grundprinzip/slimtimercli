= slimtimercli

== DESCRIPTION:

SlimTimer is a tool to record your time spend on a
task. SlimTimer CLI allows you to controll your 
SlimTimer directly from where you spend most of your
time - on the command line. To use SlimTimer proceed
with the following steps:

The first time you need to setup SlimTimer CLI with

  slimtimer setup

Now it will ask for your email and password and API key
to use with your account. These information will be stored
in ~/.slimtimer/config.yml

To create a task run

  slimtimer create_task my_shiny_task

To spend some time on the task you have to make the timer run

  slimtimer start my_shiny_task

When you finished working on a task, you can call 

  slimtimer end

This will write the time spend back to SlimTimer.com.
Finally you can run 

  slimtimer tasks

To show all your tasks available.

