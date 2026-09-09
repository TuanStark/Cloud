FROM nginxinc/nginx-unprivileged:alpine

# Copy toàn bộ mã nguồn tĩnh vào thư mục phục vụ của Nginx
COPY --chown=nginx:nginx index.html /usr/share/nginx/html/
COPY --chown=nginx:nginx app.js /usr/share/nginx/html/
COPY --chown=nginx:nginx style.css /usr/share/nginx/html/

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
