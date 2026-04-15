FROM heroiclabs/nakama:3.20.0

# Copy Lua modules
COPY backend/data/modules /nakama/data/modules

# Copy entrypoint
COPY backend/render-entrypoint.sh /nakama/render-entrypoint.sh

USER root
RUN chmod +x /nakama/render-entrypoint.sh

USER nakama

ENTRYPOINT ["/nakama/render-entrypoint.sh"]