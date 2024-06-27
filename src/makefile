MERGE		?= lmerge
LUA		?= lua5.4

SOURCES		:= rollmeow.lua helpers.lua version.lua sync.lua
OUTPUT		:= rollmeow

.PHONY: default clean

default: $(OUTPUT)

$(OUTPUT): $(SOURCES)
	$(MERGE) -ishb $(SOURCES) -o $(OUTPUT) -m rollmeow.lua -i $(LUA)

clean:
	-rm -rf $(OUTPUT)
