"use client";

import React, { useEffect, useState } from "react";
import { Cloud, Server, ShieldCheck, Globe } from "lucide-react";
import { cn } from "@/lib/utils";

export const HybridStatus = () => {
    const [provider, setProvider] = useState<string>("detecting...");
    const [cluster, setCluster] = useState<string>("");
    const [mounted, setMounted] = useState(false);

    useEffect(() => {
        setMounted(true);
        const providerEnv = process.env.NEXT_PUBLIC_CLOUD_PROVIDER || "openstack";
        const clusterEnv = process.env.NEXT_PUBLIC_CLUSTER_NAME || "foodhub-openstack";
        setProvider(providerEnv);
        setCluster(clusterEnv);
    }, []);

    if (!mounted) return null;

    const isAWS = provider.toLowerCase().includes("aws");

    return (
        <div className="fixed bottom-6 right-6 z-50 animate-in fade-in slide-in-from-bottom-10 duration-1000">
            <div className={cn(
                "flex flex-col gap-2 p-4 rounded-2xl shadow-2xl border backdrop-blur-md transition-all duration-500",
                isAWS
                    ? "bg-orange-500/10 border-orange-500/50 text-orange-600"
                    : "bg-blue-500/10 border-blue-500/50 text-blue-600"
            )}>
                <div className="flex items-center gap-3">
                    <div className={cn(
                        "p-2 rounded-full",
                        isAWS ? "bg-orange-500 text-white" : "bg-blue-500 text-white"
                    )}>
                        {isAWS ? <Cloud className="h-5 w-5" /> : <Server className="h-5 w-5" />}
                    </div>
                    <div>
                        <p className="text-[10px] uppercase tracking-widest font-bold opacity-70">Active Environment</p>
                        <h4 className="text-sm font-black flex items-center gap-1.5 uppercase tracking-tight">
                            {isAWS ? "AWS (Public Cloud)" : "OpenStack (Private Cloud)"}
                            <ShieldCheck className="h-4 w-4 text-green-500" />
                        </h4>
                    </div>
                </div>

                <div className="flex flex-col gap-1 mt-1 pt-2 border-t border-current/10">
                    <div className="flex items-center justify-between gap-10">
                        <span className="text-[10px] font-medium opacity-60">Cluster:</span>
                        <span className="text-[11px] font-bold font-mono">{cluster}</span>
                    </div>
                    <div className="flex items-center justify-between gap-10">
                        <span className="text-[10px] font-medium opacity-60">Status:</span>
                        <span className="text-[10px] flex items-center gap-1 font-bold">
                            <span className="relative flex h-2 w-2">
                                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75"></span>
                                <span className="relative inline-flex rounded-full h-2 w-2 bg-green-500"></span>
                            </span>
                            Operational
                        </span>
                    </div>
                </div>

                <div className="absolute -top-2 -right-2">
                    <div className={cn(
                        "px-2 py-0.5 rounded-full text-[9px] font-black text-white uppercase tracking-tighter shadow-sm",
                        isAWS ? "bg-orange-600" : "bg-blue-600"
                    )}>
                        Hybrid Mode
                    </div>
                </div>
            </div>
        </div>
    );
};
