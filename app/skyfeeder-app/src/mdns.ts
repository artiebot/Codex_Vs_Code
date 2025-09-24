import { useEffect, useState } from "react";

interface MdnsDevice {
  id: string;
  host: string;
}

export function useMockMdnsDevices(enabled: boolean): MdnsDevice[] {
  const [devices, setDevices] = useState<MdnsDevice[]>([]);

  useEffect(() => {
    if (!enabled) {
      setDevices([]);
      return;
    }
    // Placeholder stub. In a later step we will integrate native mDNS scanning.
    setDevices([{
      id: "sf-labgateway",
      host: "sf-labgateway.local",
    }]);
  }, [enabled]);

  return devices;
}
