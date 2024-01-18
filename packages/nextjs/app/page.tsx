"use client";

import { useState } from "react";
import Link from "next/link";
import type { NextPage } from "next";
import { useAccount } from "wagmi";
import { ArrowSmallRightIcon, XMarkIcon } from "@heroicons/react/24/outline";
import CreateMeme from "~~/components/home/CreateMeme";
import ExploreMemes from "~~/components/home/ExploreMemes";
import { useScaffoldContractWrite } from "~~/hooks/scaffold-eth";

const Home: NextPage = () => {
  const [selectedOption, setSelectedOption] = useState("create");

  const renderContent = () => {
    switch (selectedOption) {
      case "create":
        return <CreateMeme />; // Component for meme creation (the one we previously made)
      case "explore":
        return <ExploreMemes />; // Component for exploring memes
      case "portfolio":
      // return <Portfolio />; // Component for the user's portfolio
      default:
        return null;
    }
  };

  return (
    <div className="flex justify-center items-center min-h-screen bg-gray-100">
      {/* Simulated phone screen container */}
      <div className="relative w-full max-w-sm mx-auto bg-white shadow-lg" style={{ height: "640px" }}>
        {/* Content area */}
        <div className="overflow-y-auto" style={{ paddingBottom: "60px" }}>
          {renderContent()}
        </div>

        {/* Navigation bar */}
        <div className="bg-black p-4 absolute bottom-0 w-full flex justify-around text-white">
          <button
            className={`btn ${selectedOption === "create" ? "btn-active" : ""}`}
            onClick={() => setSelectedOption("create")}
          >
            Create
          </button>
          <button
            className={`btn ${selectedOption === "explore" ? "btn-active" : ""}`}
            onClick={() => setSelectedOption("explore")}
          >
            Explore
          </button>
          <button
            className={`btn ${selectedOption === "portfolio" ? "btn-active" : ""}`}
            onClick={() => setSelectedOption("portfolio")}
          >
            Portfolio
          </button>
        </div>
      </div>
    </div>
  );
};
export default Home;
