{{- define "prometheus.prometheus.yaml" -}}
rule_files:
  - /etc/config/rules
  - /etc/config/alerts

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets:
        - localhost:9090

  # A scrape configuration for running Prometheus on a Kubernetes cluster.
  # This uses separate scrape configs for cluster components (i.e. API server, node)
  # and services to allow each to use different authentication configs.
  #
  # Kubernetes labels will be added as Prometheus labels on metrics via the
  # `labelmap` relabeling action.

  # Scrape config for API servers.
  #
  # Kubernetes exposes API servers as endpoints to the default/kubernetes
  # service so this uses `endpoints` role and uses relabelling to only keep
  # the endpoints associated with the default/kubernetes service using the
  # default named port `https`. This works for single API server deployments as
  # well as HA API server deployments.
  - job_name: 'kubernetes-apiservers'

    kubernetes_sd_configs:
      - role: endpoints

    # Default to scraping over https. If required, just disable this or change to
    # `http`.
    scheme: https

    # This TLS & bearer token file config is used to connect to the actual scrape
    # endpoints for cluster components. This is separate to discovery auth
    # configuration because discovery & scraping are two separate concerns in
    # Prometheus. The discovery auth config is automatic if Prometheus runs inside
    # the cluster. Otherwise, more config options have to be provided within the
    # <kubernetes_sd_config>.
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      # If your node certificates are self-signed or use a different CA to the
      # master CA, then disable certificate verification below. Note that
      # certificate verification is an integral part of a secure infrastructure
      # so this should only be disabled in a controlled environment. You can
      # disable certificate verification by uncommenting the line below.
      #
      insecure_skip_verify: true
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

    # Keep only the default/kubernetes service endpoints for the https port. This
    # will add targets for each API server which Kubernetes adds an endpoint to
    # the default/kubernetes service.
    relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
        action: keep
        regex: default;kubernetes;https

  - job_name: 'kubernetes-nodes'

    # Default to scraping over https. If required, just disable this or change to
    # `http`.
    scheme: https

    # This TLS & bearer token file config is used to connect to the actual scrape
    # endpoints for cluster components. This is separate to discovery auth
    # configuration because discovery & scraping are two separate concerns in
    # Prometheus. The discovery auth config is automatic if Prometheus runs inside
    # the cluster. Otherwise, more config options have to be provided within the
    # <kubernetes_sd_config>.
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      # If your node certificates are self-signed or use a different CA to the
      # master CA, then disable certificate verification below. Note that
      # certificate verification is an integral part of a secure infrastructure
      # so this should only be disabled in a controlled environment. You can
      # disable certificate verification by uncommenting the line below.
      #
      insecure_skip_verify: true
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

    kubernetes_sd_configs:
      - role: node

    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
      - target_label: __address__
        replacement: kubernetes.default.svc:443
      - source_labels: [__meta_kubernetes_node_name]
        regex: (.+)
        target_label: __metrics_path__
        replacement: /api/v1/nodes/${1}/proxy/metrics

  # Scrape config for service endpoints.
  #
  # The relabeling allows the actual service scrape endpoint to be configured
  # via the following annotations:
  #
  # * `prometheus.io/scrape`: Only scrape services that have a value of `true`
  # * `prometheus.io/scheme`: If the metrics endpoint is secured then you will need
  # to set this to `https` & most likely set the `tls_config` of the scrape config.
  # * `prometheus.io/path`: If the metrics path is not `/metrics` override this.
  # * `prometheus.io/port`: If the metrics are exposed on a different port to the
  # service then set this appropriately.
  - job_name: 'kubernetes-service-endpoints'

    kubernetes_sd_configs:
      - role: endpoints

    relabel_configs:
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
        action: replace
        target_label: __scheme__
        regex: (https?)
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
        action: replace
        target_label: __address__
        regex: (.+)(?::\d+);(\d+)
        replacement: $1:$2
      - action: labelmap
        regex: __meta_kubernetes_service_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_service_name]
        action: replace
        target_label: kubernetes_name

  - job_name: 'prometheus-pushgateway'
    honor_labels: true

    kubernetes_sd_configs:
      - role: service
        namespaces:
          names: {{ .Values.kubernetes_sd_configs.namespaces }}

    relabel_configs:
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_probe]
        action: keep
        regex: pushgateway

  # Example scrape config for probing services via the Blackbox Exporter.
  #
  # The relabeling allows the actual service scrape endpoint to be configured
  # via the following annotations:
  #
  # * `prometheus.io/probe`: Only probe services that have a value of `true`
  - job_name: 'kubernetes-services'

    metrics_path: /probe
    params:
      module: [http_2xx]

    kubernetes_sd_configs:
      - role: service
        namespaces:
          names: {{ .Values.kubernetes_sd_configs.namespaces }}

    relabel_configs:
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_probe]
        action: keep
        regex: true
      - source_labels: [__address__]
        target_label: __param_target
      - target_label: __address__
        replacement: blackbox
      - source_labels: [__param_target]
        target_label: instance
      - action: labelmap
        regex: __meta_kubernetes_service_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_service_name]
        target_label: kubernetes_name

  # Example scrape config for pods
  #
  # The relabeling allows the actual pod scrape endpoint to be configured via the
  # following annotations:
  #
  # * `prometheus.io/scrape`: Only scrape pods that have a value of `true`
  # * `prometheus.io/path`: If the metrics path is not `/metrics` override this.
  # * `prometheus.io/port`: Scrape the pod on the indicated port instead of the default of `9102`.
  - job_name: 'kubernetes-pods'

    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names: {{ .Values.kubernetes_sd_configs.namespaces }}

    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: (.+):(?:\d+);(\d+)
        replacement: ${1}:${2}
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name
{{- end }}