# Variables
SOURCE_DIR = adrs
OUTPUT_FILE = adrs/complete-adrs.md
OUTPUT_DIR = adrs_split

# Target to assemble all ADRs into one file
adr-complete:
	@# Check if source directory exists
	@if [ ! -d "$(SOURCE_DIR)" ]; then \
			echo "Error: Directory $(SOURCE_DIR) not found!"; \
			exit 1; \
	fi
	@echo "Assembling ADRs in numerical order..."
	@# Remove old output file if it exists
	@rm -f $(OUTPUT_FILE)
	@# Loop through files, sort them numerically, and append to output
	@for file in $$(ls $(SOURCE_DIR)/ADR-*.md | sort); do \
			echo "Adding $$file..."; \
			cat "$$file" >> $(OUTPUT_FILE); \
			echo "---" >> $(OUTPUT_FILE); \
			echo "\n" >> $(OUTPUT_FILE); \
	done
	@echo "Success: $(OUTPUT_FILE) has been created."

# Target to remove generated files
clean:
	@echo "Cleaning up..."
	@rm -f $(OUTPUT_FILE)

split-adrs:
	@mkdir -p $(OUTPUT_DIR)
	@python3 split.py

# Clean up the split directory
clean-split:
	rm -rf $(OUTPUT_DIR)