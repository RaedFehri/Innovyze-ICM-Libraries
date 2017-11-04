# ICMExchange (Ruby) - Cross script data sharing

When writing software it is often useful to keep track of changes made by the user. For this you need to be able to store data until it's required in the future. When making ruby applications in ICM, the same is true but ICM provides no way to access data between scripts. Or does it?

To investigate further we need to explore how the ruby runtime in ICM, or at least, an accurate representation of how it works.

The first thing to note about the ruby runtime in ICM, is that ICM always appears to use the same virtual machine to run all ruby scripts in one process. You can see it as the following example:

```ruby
class Sandbox
end

Sandbox.new.instance_eval(rubyCode)
```

As shown, each time the code is evaluated, it is done so in it's own new instance of a ruby Sandbox object using instance_eval.  This is important because it means that ruby scripts can't intentionally interact with eachother. I.E. The local variables of one ruby script are not accessible from the local variables from another. To see this in action run the following ruby script in [a ruby REPL](https://repl.it/languages/ruby):

```ruby
class Sandbox
end

Sandbox.new.instance_eval("
  local = 'abc'
")

puts "---"

puts Sandbox.new.instance_eval("local")

puts "---"
```

You should see the following will be outputted:

```
---
undefined local variable or method `local' for #<Sandbox:0x0055c5dbccbab8>
(repl):10:in `instance_eval'
(repl):10:in `instance_eval'
(repl):10:in `<main>'
```

As shown, the variable "local" is not accessible in the second instance of the Sandbox object, even though a variable with the same name was set earlier in an old Sandbox object. The thing to notice however is that in the Sandbox example we are doing nothing to stop users writing to `Class` variables or `Global` variables:

```ruby
class Sandbox
end

Sandbox.new.instance_eval("
  $global = 'abc'
  @@class = 'def'
")

puts "---"

puts Sandbox.new.instance_eval("$global")
puts Sandbox.new.instance_eval("@@class")

puts "---"
```

The above code should return this to the console:

```
 ---
 abc
 def
 ---
=> nil
```

ICM's Ruby virtual machine works in exactly the same way to this, and I wouldn't be surprised if the implementation was identical. The important thing to note though is this allows us to share data between scripts ran in the **same instance** of ICM, **in-process** without the need for any external files.

To make this local stroage easier to manage, I've made a class to easily give you access to global storage for your application. This works through an 'identifier' system. In the end, we'd rather not have many global variables pollution the global namespace. It is better to build all variables into a single global variable.

## So what?

So what's the use of this behaviour? Let's look at an example.

Say you want to make a ruby application which helps users build selection lists from the ground up. Traditionally in ICM there is no way to 'build up' a selection list. You can make a selection, and then make a selection list from your selection, but if you want to overwrite your existing selection list with a new one, there is no easy way to do this. Instead let's build a set of scripts which helps users build up, overwrite, delete from and clear their selection lists.

The different script files we'll make are the following:

```
SL_Select.rb
SL_Append.rb
SL_Remove.rb
SL_Clear.rb
SL_Overwrite.rb
```

We will first select a selection list. The easiest way to do this is by providing the ID of the selection list to operate on. This is where `SL_Select.rb` comes in handy. `SL_Select.rb` will select the selection list to operate on and store this data in a `WSLocalStorage` object. From here it can easily be accessed for `SL_Append`, `SL_Remove`, `SL_Clear` and `SL_Overwrite` operations.

**SL_Select.rb**

```ruby
#'Selection List' operations GUID: a8344089-9f06-4058-9955-57283c090659
localStorage = WSLocalStorage.new("a8344089-9f06-4058-9955-57283c090659")
localStorage["id"] = WSApplication.input_box("Enter selection list ID:", "Select selection list", "").to_i

#Check that model object is of type selection list:
iwdb = WSApplication.current_database
if !iwdb.model_object_from_type_and_id("Selection list",localStorage["id"])
  localStorage["id"] = 0
  WSApplication.message_box("ID selected is not the ID of a selection list.","!","OK",nil)
end
```

Here we create a new object with our application identifier as a name. I greated this application identifier by going to [this website](https://www.guidgen.com/) and copying the GUID/UUID generated. The reason programmers use GUIDs is because the probability of them not being unique is tiny.

> While each generated GUID is not guaranteed to be unique, the total number of unique keys (2^128 or 3.4×10^38) is so large that the probability of the same number being generated twice is very small. For example, consider the observable universe, which contains about 5×10^22 stars; every star could then have 6.8×10^15 universally unique GUIDs.

For this reason we are creating almost certainty that our application id is unique and not going to clash with any other applications anyone else has made. Then we set the `id` key of our personal application space to the ID of a selection list given by the user. Afterwards we check whether the ID provided is indeed a selection list. If not then we notify the user of their mistakes and set the `id` key of our personal application space to `0`, which ensures that no further operations will be run on this id. Next, let's work on the operations.

**SL_Append.rb**

```ruby
localStorage = WSLocalStorage.new("a8344089-9f06-4058-9955-57283c090659")
if localStorage["id"] && localStorage["id"] != 0
  WSApplication.load_selection localStorage["id"]		#Add the old selection list to the current selection
  WSApplication.save_selection localStorage["id"]		#Save the selection
end
```

Here we use our application identifier to grab the current localStorage object currently setup by SL_Select. Then we make sure the id stored in the application is non `0` and non `nil`. This prevents errors discussed earlier. Then we use this ID to load the selection list. When using `load_seletion` ICM actually appends the selection list to the current selection (as if you were holding control while draggin the selection list). Ultimately ICM has already done the job of appending the selection lists for us, now we just need to save the changes, which we do with `save_selection`.

**SL_Remove.rb**

```ruby
localStorage = WSLocalStorage.new("a8344089-9f06-4058-9955-57283c090659")
if localStorage["id"] && localStorage["id"] != 0
  net = WSApplication.current_network
  to_remove = {}
  net.table_names.each do |table|
    to_remove[table] = []
    net.row_object_collection_selection(table).each do |ro|
      to_remove[table].push(ro.id)
    end
  end
  
  net.clear_selection
  net.load_selection localStorage["id"]
  
  net.table_names.each do |table|
    try_remove = to_remove[table]
    net.row_object_collection_selection(table).each do |ro|
      if try_remove.index ro.id
        ro.selected = false
      end
    end
  end
  
  net.save_selection localStorage["id"]
end
```

`SL_Remove` is slightly more complicated. To summarise, we firstly store the current selection in an object, which afterwards we can use as a lookup to find those objects with IDs which shouldn't be selected. From this, after loading the selection list, we can easily deselect those parts which shouldn't be selected. At the end of the operation we save the selection list, saving our changes.

**SL_Clear.rb**

```ruby
localStorage = WSLocalStorage.new("a8344089-9f06-4058-9955-57283c090659")
if localStorage["id"] && localStorage["id"] != 0
  net = WSApplication.current_network
  net.clear_selection
  net.save_selection localStorage["id"]
end
```

Going back to the easier operations, to clear the selection list, we simply save a blank selection list to the current chosen selection list.

**SL_Overwrite.rb**

```ruby
localStorage = WSLocalStorage.new("a8344089-9f06-4058-9955-57283c090659")
if localStorage["id"] && localStorage["id"] != 0
  WSApplication.current_network.save_selection localStorage["id"]
end
```

And to finish it off, to overwrite a selection list, we simply save the current selection list to the current chosen selection list.

With the above ruby scripts we can have much more flexibility over our selection lists in InfoWorks ICM and InfoNet. Feel free to comment your own ideas which can use this library!
