#!/bin/bash
# Health check script for Consul DNS-based service discovery

set -e

CONSUL_SERVER="$1"
WEB_SERVICE_NAME="${2:-web}"

if [ -z "$CONSUL_SERVER" ]; then
    echo "Usage: $0 <consul_server_ip> [service_name]"
    exit 1
fi

echo "========================================="
echo "Consul DNS Health Check Script"
echo "========================================="
echo ""

# Check Consul cluster health
echo "1. Checking Consul cluster health..."
consul_members=$(ssh ubuntu@${CONSUL_SERVER} "/opt/consul/bin/consul members" 2>/dev/null || echo "Unable to connect")
echo "$consul_members"
echo ""

# Check registered services
echo "2. Checking registered services in Consul..."
services=$(ssh ubuntu@${CONSUL_SERVER} "curl -s http://localhost:8500/v1/agent/services" 2>/dev/null || echo "{}")
echo "$services" | jq -r 'keys[]' | while read service; do
    echo "  - $service"
done
echo ""

# Check DNS resolution for the service
echo "3. Checking DNS resolution for ${WEB_SERVICE_NAME}.service.consul..."
dns_results=$(dig @${CONSUL_SERVER} -p 8600 ${WEB_SERVICE_NAME}.service.consul +short 2>/dev/null || echo "")
if [ -n "$dns_results" ]; then
    echo "DNS resolves to:"
    echo "$dns_results" | while read ip; do
        echo "  - $ip"
        # Try to ping the IP
        if ping -c 1 -W 1 "$ip" >/dev/null 2>&1; then
            echo "    ✓ IP is reachable"
        else
            echo "    ✗ IP is NOT reachable"
        fi
    done
else
    echo "  ✗ No DNS records found"
fi
echo ""

# Check service health endpoint
echo "4. Checking service health status..."
health_status=$(ssh ubuntu@${CONSUL_SERVER} "curl -s http://localhost:8500/v1/health/service/${WEB_SERVICE_NAME}" 2>/dev/null || echo "[]")
healthy_count=$(echo "$health_status" | jq '[.[] | select(.Checks[] | select(.Status == "passing"))] | length')
total_count=$(echo "$health_status" | jq '. | length')
echo "Healthy services: $healthy_count / $total_count"
echo ""

# Details of each service instance
echo "5. Service instances details:"
echo "$health_status" | jq -r '.[] | "  \(.Service.Address):\(.Service.Port) - Status: \((.Checks[] | select(.CheckID == "service:' + ${WEB_SERVICE_NAME} + '")).Status // "unknown")"'
echo ""

# Test DNS round-robin
echo "6. Testing DNS round-robin (3 queries)..."
for i in {1..3}; do
    dns_result=$(dig @${CONSUL_SERVER} -p 8600 ${WEB_SERVICE_NAME}.service.consul +short 2>/dev/null | head -1)
    echo "  Query $i: $dns_result"
done
echo ""

# Summary
echo "========================================="
echo "Summary"
echo "========================================="
if [ "$healthy_count" -gt 0 ]; then
    echo "✓ Service discovery is working"
    echo "✓ DNS resolution is functional"
    if [ "$healthy_count" -eq "$total_count" ]; then
        echo "✓ All service instances are healthy"
    else
        echo "⚠ Some service instances are unhealthy"
    fi
else
    echo "✗ No healthy service instances found"
fi
echo ""

