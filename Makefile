.PHONY: build preview data clean

build:
	yarn build

preview:
	yarn preview

data:
	@mkdir -p data
	@echo "Fetching repository data from GitHub API..."
	gh api "/orgs/data-desk-eco/repos" --paginate -q \
		'[.[] | select(.name != "data-desk-eco.github.io" and .private == false and .has_pages == true and .description != null and .description != "") | {name: .name, description: .description, url: "https://research.datadesk.eco/\(.name)/", repo_url: .html_url, created_at: .created_at}]' \
		| duckdb data/data.duckdb "CREATE OR REPLACE TABLE projects AS SELECT * FROM read_json('/dev/stdin')"
	@echo "Data updated"

robots:
  	printf 'User-agent: *\nDisallow: /\n' > docs/robots.txt

clean:
	rm -rf docs/.observable/dist
