"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import type { NextPage } from "next";
import { formatUnits } from "viem";
import { useAccount } from "wagmi";
import { useScaffoldContractRead } from "~~/hooks/scaffold-eth";

const ExploreMemes = () => {
  const [memes, setMemes] = useState([]);
  const { data: memeCount } = useScaffoldContractRead({
    contractName: "MemeMulticall",
    functionName: "getMemeCount",
  });

  const { data: fetchedMemes } = useScaffoldContractRead({
    contractName: "MemeMulticall",
    functionName: "getMemeDataIndexes",
    args: [BigInt(1), BigInt(memeCount || 0) + BigInt(1), "0x0000000000000000000000000000000000000000"],
    watch: true,
  });

  useEffect(() => {
    if (fetchedMemes) {
      setMemes(fetchedMemes);
    }
  }, [fetchedMemes]);

  // Render memes
  return (
    <div className="container mx-auto">
      {memes.map((meme, index) => {
        // Format marketPrice using formatUnits to convert from Wei to Ether
        const formattedPrice =
          meme.marketPrice !== undefined ? `${parseFloat(formatUnits(meme.marketPrice, 18)).toFixed(4)} ETH` : "N/A";

        return (
          <div key={index} className="meme-card bg-white p-4 border border-gray-200 rounded-lg my-2 flex">
            <div className="flex-none" style={{ width: "100px", height: "100px" }}>
              <img src={meme.uri} alt={meme.name} className="object-cover object-center w-full h-full" />
            </div>
            <div className="flex-grow ml-4">
              <div className="flex justify-between items-start">
                <div>
                  <h3 className="font-bold">{meme.symbol}</h3>
                  <h3 className="text-gray-600">{meme.name}</h3>
                  <p className="mt-2 text-sm">{meme.status}</p>
                </div>
                <div className="text-right">
                  {/* Display the formatted market price */}
                  <span className="font-semibold text-sm">{formattedPrice}</span>
                </div>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
};

export default ExploreMemes;
