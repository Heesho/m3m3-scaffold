"use client";

import { useState } from "react";
import Link from "next/link";
import type { NextPage } from "next";
import { useAccount } from "wagmi";
import { ArrowSmallRightIcon, XMarkIcon } from "@heroicons/react/24/outline";
import { useScaffoldContractWrite } from "~~/hooks/scaffold-eth";

const CreateMeme: NextPage = () => {
  const { address: connectedAddress } = useAccount();
  const [name, setName] = useState("");
  const [symbol, setSymbol] = useState("");
  const [uri, setUri] = useState("");

  const { writeAsync: createMeme, isLoading } = useScaffoldContractWrite({
    contractName: "MemeRouter",
    functionName: "createMeme",
    args: [name, symbol, uri],
    value: BigInt(100000000000000000),
    onBlockConfirmation: txnReceipt => {
      console.log("📦 Transaction blockHash", txnReceipt.blockHash);
    },
  });

  return (
    <div className="bg-white rounded-xl shadow-lg p-6 max-w-md mx-auto flex flex-col items-center">
      <h1 className="text-3xl font-bold mb-4">Create a Meme</h1>
      <div className="space-y-4 w-full">
        <input
          type="text"
          placeholder="Name"
          className="input input-bordered w-full"
          value={name}
          onChange={e => setName(e.target.value)}
        />
        <input
          type="text"
          placeholder="Symbol"
          className="input input-bordered w-full"
          value={symbol}
          onChange={e => setSymbol(e.target.value.toUpperCase())}
        />
        <input
          type="text"
          placeholder="URI"
          className="input input-bordered w-full"
          value={uri}
          onChange={e => setUri(e.target.value)}
        />
      </div>
      <div className="flex justify-between items-center w-full mt-4">
        <span className="text-lg font-semibold">Price: 0.1 ETH + Gas</span>
        <button
          className={`btn ${
            isLoading ? "loading" : ""
          } bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded shadow-lg`}
          onClick={() => createMeme()}
          disabled={isLoading}
        >
          {isLoading ? <span className="loading-spinner"></span> : "Create"}
        </button>
      </div>
      {/* Meme Preview */}
      <div className="w-full bg-gray-200 mt-4 p-4 flex justify-center items-center overflow-hidden">
        <img src={uri || "https://via.placeholder.com/150"} alt="Meme Preview" className="object-cover w-32 h-32" />
        <div className="ml-4">
          <h3 className="font-bold uppercase">{symbol || "Symbol"}</h3>
          <h3>{name || "Meme Name"}</h3>
        </div>
      </div>
    </div>
  );
};

export default CreateMeme;
