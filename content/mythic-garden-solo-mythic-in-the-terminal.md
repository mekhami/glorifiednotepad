---
title: "Mythic Garden: Solo Mythic in the Terminal"
id: "mythic-garden-solo-mythic-in-the-terminal"
date: 2026-04-19
width: 60%
draft: false
---

# Mythic Garden!

Mythic! Mythic GME is how I've come to understand solo games. It was hard for me to really wrap my head around the large structures of solo play until I found mythic and it's incredibly diverse set of tools, techniques, supplements, and advices. It's a very common tool in the Solo RPG world, so I won't belabor my introduction to it.

What I struggled with (and this is probably due to my severe, unmedicated ADHD...) is the flipping and forth between different PDFs, different articles, diverse tables, and discrete processes to make the whole thing come together. Each little subsystem has a procedure, and while of course you can leave those processes behind and do your own thing, I do find these processes have a ton of value. So, rather than just enduring with the challenge, I made a tool to help me do it all with less friction.

Introducing mythic.garden! It's a Terminal UI tool that is publicly accessible via ssh! (If you don't what that means... I'm sorry, this tool probably won't be for you. Feel free to check out the pretty screenshots, though!)

You can access it now with `ssh mythic.garden`. You will be prompted to accept the host key fingerprint - this is unavoidable, as it's the most basic step of SSH. After that, you'll be prompted to login with a username and password, and you can enter whatever you like here. It's encrypted, never stored in plaintext, and no email registration or anything like that. Absolutely dead simple cause I'm not interested in your deets.

# Session Notes and Lists

The core of Mythic is scenes and lists. This tool supports scenes, creating new scenes, rolling interrupts and alterations, chaos factor, character lists, thread lists. You take your notes in the notes area and they are always saved (even if you disconnect from the tool in a weird way.) You can add your characters and threads according to Mythic's rules. You can change anything at any time as well, so you're never locked in to anything.

![mythic session notes](images/session-complete-scene.png)

When you add a new scene, a helpful wizard walks you through the steps and rolls some dice for you.

[video:/videos/new-scene-flow.mp4] 

# Miscellaneous Tools

On top of the basics of scenes and lists, you need Fate checks and Meaning tables. Whaddya know, those are here too!

![mythic fate check interface](images/fate-check-result.png)

[video:/videos/meaning-table-roller.mp4]

![the list of meaning tables](images/meaning-table-list.png)

And if you need to roll some random dice arbitrarily for your system, here's a fun way to do that:

[video:/videos/dice-roller-8d10.mp4]

My preferred notetaking method is Lonelog, and I think more people should know about it. So I added a helpful little popup that will remind you of Lonelog syntax, which you can see I used in the scene above.

![lonelog modal showing the lonelog syntax reference](images/lonelog-legend.png)

# Tools

The vast majority of what's available in Mythic Garden are the tools. Each of these comes from Mythic and supplements your games in different ways. Right now, they are the Fantasy World Crafter, the Adventure Crafter, the Location Crafter, and the Backstory Generator. There are so many more in the Mythic Magazine collections - I just haven't gotten time to implement them yet! But rest assured, when I need them in my game, they'll be available in the Garden.

## Fantasy World Crafter


If you don't know what you want to play yet, Mythic introduced the Fantasy World Crafter in Mythic Magazine vol. 60! This cool system walks you through the big ideas of a fantasy world, gives you new tables to roll on for inspiration, and sets you up with adventure seeds and a d20 table specific to your setting for future mechanics.

![fantasy world crafter interface](images/fwc-dashboard.png)

Each of the boxes is one part of how your world is defined. When you open it, it'll automatically roll for you, and you can always choose to re-roll.

![fantasy world crafter interface](images/fwc-node.png)

The adventure seeds will give you ideas to kickstart your solo campaign. Also note that in each of these views, there's an info panel helping you understand the choices you're making and how they will impact your game.

![fantasy world crafter interface](images/fwc-adventure-seed.png)

The World Meaning Table is basically a custom table for your setting, built off of the choices and results of previous steps. Helpful for capturing the flavor of your creation and channeling it into future results.

![fantasy world crafter interface](images/fwc-wmt.png)

## The Adventure Crafter

What solo campaign is complete without adventures? The Adventure Crafter is one of Mythic's main offerings apart from the Game Master Emulator. It's the tool that I use more than any other. It's valuable for rolling up entire stories, or just starting scenes, or anything in between.

![the adventure crafter interface](images/tac-complete.png)

All of the tables and mechanics of The Adventure Crafter are included in the tool (which are graciously available under the CC-BY license, without which this project would not be publicly possible!) Apart from Turning Point generation, characters and plotlines operate identically to other Mythic lists.

## The Location Crafter

The Location Crafter is a tool I haven't personally gotten to use, but it's one I think has a ton of potential value. I just haven't had a great reason to use it yet. I'm eagerly awaiting the opportunity though, because it's a very interesting looking system that could provide dynamic, surprising results. And we love surprising results in Mythic!

![the location crafter interface](images/lc-encounters.png)

![the location crafter interface](images/lc-rolled-location.png)

## Backstory Generator

Last but certainly not least, the Backstory Generator is one of the tools I rely on the most. You can explore the backstory of anything - characters, NPCs, locations, objects, ideas, religions, gods... whatever you are interested in! The system is abstract enough to support virtually any kind of story telling.

![backstory generator, new thread](images/backstory-new-thread.png)

![backstory generator, in progress](images/backstory-inprogress.png)

![backstory generator, completed backstory](images/backstory-complete.png)

This backstory is for the main character of my solo Legend in the Mist game, and I'm always very pleased with the results.

# Wrap-up

Well, that's what's in Mythic Garden right now! If you like, give it a whirl. When you're done, you can export all of your content, and it will be emailed to you. (I still do not nor will I ever collect your email address.) What'syours is yours! If you check it out and make something cool, and want to share it with me, PLEASE do. I'd get a big kick out of that.

If there's a feature or tool you'd like to see, let me know!

Or, far more likely, if you find a bug, I'd love to know about that too.

Thanks, have fun soloing!
