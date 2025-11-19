.PHONY: dev setup down logs shell test clean rebuild

# Start development server
dev:
	docker compose up

# Initial setup (build, create DB, run migrations)
setup:
	docker compose build
	mkdir -p data
	docker compose run --rm app mix ecto.create
	docker compose run --rm app mix ecto.migrate
	@echo "Setup complete! Run 'make dev' to start the server."

# Stop all containers
down:
	docker compose down

# View logs
logs:
	docker compose logs -f app

# Open IEx shell in running container
shell:
	docker compose exec app iex -S mix

# Run tests
test:
	docker compose run --rm app mix test

# Clean build artifacts
clean:
	docker compose down -v
	rm -rf _build deps data

# Rebuild everything from scratch
rebuild: clean
	docker compose build --no-cache
	$(MAKE) setup
